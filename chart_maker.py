import os
import getpass

import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine


# ---------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------
DB_USER = "root"
DB_HOST = "localhost"
DB_PORT = 3306
DB_NAME = "airbnb_market"

OUTPUT_DIR = "charts"
DATA_NOTE = "Sample data for illustration, not real market figures"

# Colors (colorblind-safe palette)
BLUE = "#2a78d6"
ORANGE = "#eb6834"
AQUA = "#1baf7a"
GRAY = "#b5b3ad"
TEXT_DARK = "#0b0b0b"
TEXT_SOFT = "#52514e"

HOST_TYPE_COLORS = {
    "individual": BLUE,
    "professional": ORANGE,
    "commercial": AQUA,
}

# Nicer names for stakeholders
REGULATION_LABELS = {
    "night_cap": "Night limit",
    "registration_requirement": "Registration required",
    "suspension_zone": "No new licenses",
    "short_term_rental_ban": "Full ban",
}
PROPERTY_LABELS = {
    "apartment": "Apartment",
    "house": "House",
    "studio": "Studio",
    "loft": "Loft",
    "room": "Room",
}


# ---------------------------------------------------------------------
# SQL queries (same as 04_advanced_queries.sql, except where marked)
# ---------------------------------------------------------------------
QUERY_1 = """
SELECT
    c.name                              AS city,
    n.name                              AS neighborhood,
    COUNT(DISTINCT l.listing_id)        AS active_listings,
    ROUND(AVG(latest.nightly_price), 2) AS avg_nightly_price,
    ROUND(MIN(latest.nightly_price), 2) AS min_nightly_price,
    ROUND(MAX(latest.nightly_price), 2) AS max_nightly_price
FROM neighborhood n
JOIN city c     ON c.city_id = n.city_id
JOIN property p ON p.neighborhood_id = n.neighborhood_id
JOIN listing l  ON l.property_id = p.property_id
JOIN listing_snapshot latest
     ON latest.listing_id = l.listing_id
    AND latest.snapshot_date = (
        SELECT MAX(ls2.snapshot_date)
        FROM listing_snapshot ls2
        WHERE ls2.listing_id = l.listing_id
    )
WHERE latest.active = TRUE
GROUP BY c.name, n.name
ORDER BY avg_nightly_price DESC
"""

QUERY_2 = """
SELECT
    h.host_id,
    h.host_type,
    h.verified,
    COUNT(DISTINCT hp.property_id) AS properties_owned,
    COUNT(DISTINCT l.listing_id)   AS total_listings
FROM host h
JOIN host_property hp ON hp.host_id = h.host_id
LEFT JOIN listing l   ON l.host_id = h.host_id
GROUP BY h.host_id, h.host_type, h.verified
HAVING COUNT(DISTINCT hp.property_id) > 1
ORDER BY properties_owned DESC, total_listings DESC
"""

QUERY_3 = """
SELECT
    n.name AS neighborhood,
    l.listing_id,
    p.property_type,
    latest.nightly_price,
    RANK() OVER (
        PARTITION BY n.neighborhood_id
        ORDER BY latest.nightly_price DESC
    ) AS price_rank_in_neighborhood
FROM listing l
JOIN property p     ON p.property_id = l.property_id
JOIN neighborhood n ON n.neighborhood_id = p.neighborhood_id
JOIN listing_snapshot latest
     ON latest.listing_id = l.listing_id
    AND latest.snapshot_date = (
        SELECT MAX(ls2.snapshot_date)
        FROM listing_snapshot ls2
        WHERE ls2.listing_id = l.listing_id
    )
ORDER BY n.name, price_rank_in_neighborhood
"""

QUERY_4 = """
WITH listing_growth AS (
    SELECT
        ls.listing_id,
        ls.snapshot_date,
        ls.nightly_price,
        LAG(ls.nightly_price) OVER (
            PARTITION BY ls.listing_id ORDER BY ls.snapshot_date
        ) AS previous_price
    FROM listing_snapshot ls
),
rent_growth AS (
    SELECT
        hmo.neighborhood_id,
        hmo.observation_date,
        hmo.avg_rent_per_m2,
        LAG(hmo.avg_rent_per_m2) OVER (
            PARTITION BY hmo.neighborhood_id ORDER BY hmo.observation_date
        ) AS previous_rent
    FROM housing_market_observation hmo
)
SELECT
    n.name AS neighborhood,
    l.listing_id,
    lg.snapshot_date,
    ROUND(100 * (lg.nightly_price - lg.previous_price) / lg.previous_price, 2) AS listing_price_growth_pct,
    ROUND(100 * (rg.avg_rent_per_m2 - rg.previous_rent) / rg.previous_rent, 2) AS neighborhood_rent_growth_pct
FROM listing_growth lg
JOIN listing l      ON l.listing_id = lg.listing_id
JOIN property p     ON p.property_id = l.property_id
JOIN neighborhood n ON n.neighborhood_id = p.neighborhood_id
JOIN rent_growth rg ON rg.neighborhood_id = n.neighborhood_id
                   AND rg.observation_date = '2024-04-01'
WHERE lg.previous_price IS NOT NULL
ORDER BY neighborhood, l.listing_id, lg.snapshot_date
"""

# Two fixes compared to 04_advanced_queries.sql:
#   (a) the rule must already have started (effective_from <= today),
#       otherwise the Barcelona 2028 ban counts as active today.
#   (b) only active listings are checked. Listing 8 is inactive
#       (0 available days because it is closed), so without this
#       it counts as "365 nights booked".
QUERY_5 = """
SELECT
    n.name                       AS neighborhood,
    r.regulation_type,
    r.annual_night_limit,
    COUNT(DISTINCT l.listing_id) AS total_listings,
    SUM(
        CASE
            WHEN r.annual_night_limit IS NOT NULL
             AND (365 - latest.available_days_next_365) > r.annual_night_limit
            THEN 1 ELSE 0
        END
    ) AS listings_over_limit
FROM regulation r
JOIN regulation_area ra ON ra.regulation_id = r.regulation_id
JOIN neighborhood n     ON n.neighborhood_id = ra.neighborhood_id
JOIN property p         ON p.neighborhood_id = n.neighborhood_id
JOIN listing l          ON l.property_id = p.property_id
JOIN listing_snapshot latest
     ON latest.listing_id = l.listing_id
    AND latest.snapshot_date = (
        SELECT MAX(ls2.snapshot_date)
        FROM listing_snapshot ls2
        WHERE ls2.listing_id = l.listing_id
    )
WHERE r.effective_from <= CURDATE()
  AND (r.effective_to IS NULL OR r.effective_to >= CURDATE())
  AND latest.active = TRUE
GROUP BY n.name, r.regulation_type, r.annual_night_limit
ORDER BY listings_over_limit DESC
"""


# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------
def set_style():
    plt.rcParams["font.family"] = "DejaVu Sans"
    plt.rcParams["font.size"] = 13
    plt.rcParams["axes.titlesize"] = 18
    plt.rcParams["axes.titleweight"] = "bold"
    plt.rcParams["axes.titlelocation"] = "left"
    plt.rcParams["axes.titlepad"] = 16
    plt.rcParams["axes.edgecolor"] = GRAY
    plt.rcParams["axes.labelcolor"] = TEXT_SOFT
    plt.rcParams["xtick.color"] = TEXT_SOFT
    plt.rcParams["ytick.color"] = TEXT_SOFT
    plt.rcParams["axes.spines.top"] = False
    plt.rcParams["axes.spines.right"] = False
    plt.rcParams["figure.facecolor"] = "white"


def new_figure():
    # 16:9 so it fits a slide
    fig, ax = plt.subplots(figsize=(12.8, 7.2))
    return fig, ax


def light_grid(ax, axis):
    ax.grid(axis=axis, color="#e6e5e1", linewidth=1)
    ax.set_axisbelow(True)


def save(fig, file_name):
    fig.text(0.01, 0.015, DATA_NOTE, fontsize=10, color=TEXT_SOFT, style="italic")
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    path = os.path.join(OUTPUT_DIR, file_name)
    fig.savefig(path, dpi=200)
    plt.close(fig)
    print("Saved " + path)


def label_bars(ax, bars, text_list, horizontal):
    for i in range(len(bars)):
        bar = bars[i]
        text = text_list[i]
        if horizontal:
            x = bar.get_width()
            y = bar.get_y() + bar.get_height() / 2
            ax.annotate(text, (x, y), xytext=(6, 0), textcoords="offset points",
                        va="center", ha="left", color=TEXT_DARK, fontsize=12)
        else:
            x = bar.get_x() + bar.get_width() / 2
            y = bar.get_height()
            if y >= 0:
                offset = 5
                vertical = "bottom"
            else:
                offset = -5
                vertical = "top"
            ax.annotate(text, (x, y), xytext=(0, offset), textcoords="offset points",
                        va=vertical, ha="center", color=TEXT_DARK, fontsize=12)


# ---------------------------------------------------------------------
# Chart 1: price per night by neighborhood
# ---------------------------------------------------------------------
def chart_1(df):
    df = df.sort_values("avg_nightly_price", ascending=True)

    names = []
    for i in range(len(df)):
        row = df.iloc[i]
        names.append(row["neighborhood"] + " (" + row["city"] + ")")

    prices = df["avg_nightly_price"].astype(float).tolist()

    fig, ax = new_figure()
    bars = ax.barh(names, prices, color=BLUE, height=0.6)

    labels = []
    for p in prices:
        labels.append("€" + str(round(p)))
    label_bars(ax, bars, labels, horizontal=True)

    ax.set_title("Where tourists pay the most per night")
    ax.set_xlabel("Average price per night (EUR), active listings, June 2024")
    ax.set_xlim(0, max(prices) * 1.15)
    light_grid(ax, "x")
    save(fig, "q1_price_per_neighborhood.png")


# ---------------------------------------------------------------------
# Chart 2: hosts with more than one home
# ---------------------------------------------------------------------
def chart_2(df):
    df = df.sort_values(["properties_owned", "total_listings"], ascending=True)

    names = []
    colors = []
    for i in range(len(df)):
        row = df.iloc[i]
        names.append("Host " + str(row["host_id"]))
        colors.append(HOST_TYPE_COLORS[row["host_type"]])

    homes = df["properties_owned"].astype(int).tolist()
    listings = df["total_listings"].astype(int).tolist()

    fig, ax = new_figure()
    bars = ax.barh(names, homes, color=colors, height=0.6)

    labels = []
    for i in range(len(homes)):
        if listings[i] == 1:
            ads = " ad"
        else:
            ads = " ads"
        labels.append(str(homes[i]) + " homes, " + str(listings[i]) + ads + " online")
    label_bars(ax, bars, labels, horizontal=True)

    # Legend for host types (only the types that appear)
    handles = []
    for host_type in HOST_TYPE_COLORS:
        if host_type in df["host_type"].values:
            patch = plt.Rectangle((0, 0), 1, 1, color=HOST_TYPE_COLORS[host_type])
            handles.append((patch, host_type.capitalize()))
    ax.legend([h[0] for h in handles], [h[1] for h in handles],
              title="Type of host", frameon=False, loc="lower right")

    ax.set_title("Some hosts run several homes, like a small business")
    ax.set_xlabel("Number of homes owned or managed")
    ax.set_xlim(0, max(homes) + 1.5)
    ax.xaxis.set_major_locator(plt.MaxNLocator(integer=True))
    light_grid(ax, "x")
    save(fig, "q2_multi_home_hosts.png")


# ---------------------------------------------------------------------
# Chart 3: ranking table inside each neighborhood
# ---------------------------------------------------------------------
def chart_3(df):
    rows = []
    last_neighborhood = None
    for i in range(len(df)):
        row = df.iloc[i]
        # Show the neighborhood name only on its first line
        if row["neighborhood"] == last_neighborhood:
            neighborhood_text = ""
        else:
            neighborhood_text = row["neighborhood"]
        last_neighborhood = row["neighborhood"]

        home_type = PROPERTY_LABELS[row["property_type"]]
        rows.append([
            neighborhood_text,
            "#" + str(int(row["price_rank_in_neighborhood"])),
            home_type + " (listing " + str(row["listing_id"]) + ")",
            "€" + str(round(float(row["nightly_price"]))),
        ])

    fig, ax = new_figure()
    ax.axis("off")
    table = ax.table(
        cellText=rows,
        colLabels=["Neighborhood", "Rank", "Home", "Price per night"],
        colWidths=[0.28, 0.12, 0.36, 0.2],
        cellLoc="left",
        loc="upper center",
    )
    table.auto_set_font_size(False)
    table.set_fontsize(13)
    table.scale(1, 1.9)

    for (r, c), cell in table.get_celld().items():
        cell.set_edgecolor("#e6e5e1")
        cell.set_linewidth(0.8)
        if r == 0:
            cell.set_text_props(weight="bold", color="white")
            cell.set_facecolor(BLUE)
        else:
            # Light band on each neighborhood's first row
            if rows[r - 1][0] != "":
                cell.set_text_props(weight="bold")

    ax.set_title("How each home ranks on price in its own neighborhood")
    save(fig, "q3_price_rank_table.png")


# ---------------------------------------------------------------------
# Chart 4: tourist price growth vs long-term rent growth
# ---------------------------------------------------------------------
def chart_4(df):
    df = df.copy()
    df["listing_price_growth_pct"] = df["listing_price_growth_pct"].astype(float)
    df["neighborhood_rent_growth_pct"] = df["neighborhood_rent_growth_pct"].astype(float)

    # One row per neighborhood: average monthly growth
    summary = df.groupby("neighborhood", as_index=False).agg(
        tourist=("listing_price_growth_pct", "mean"),
        rent=("neighborhood_rent_growth_pct", "mean"),
    )
    summary = summary.sort_values("tourist", ascending=False)

    names = summary["neighborhood"].tolist()
    tourist = summary["tourist"].tolist()
    rent = summary["rent"].tolist()

    positions = list(range(len(names)))
    width = 0.38
    left = []
    right = []
    for p in positions:
        left.append(p - width / 2 - 0.01)
        right.append(p + width / 2 + 0.01)

    fig, ax = new_figure()
    bars_tourist = ax.bar(left, tourist, width, color=ORANGE,
                          label="Tourist price per night (average monthly growth, April to June 2024)")
    bars_rent = ax.bar(right, rent, width, color=BLUE,
                       label="Long-term rent per m² (growth, January to April 2024)")

    tourist_labels = []
    for value in tourist:
        tourist_labels.append(str(round(value, 1)) + "%")
    rent_labels = []
    for value in rent:
        rent_labels.append(str(round(value, 1)) + "%")
    label_bars(ax, bars_tourist, tourist_labels, horizontal=False)
    label_bars(ax, bars_rent, rent_labels, horizontal=False)

    ax.set_xticks(positions)
    ax.set_xticklabels(names)
    ax.set_ylabel("Growth (%)")
    ax.set_ylim(0, max(max(tourist), max(rent)) * 1.3)
    ax.axhline(0, color=GRAY, linewidth=1)
    ax.legend(frameon=False, loc="upper right", fontsize=11)
    ax.set_title("Tourist prices grow faster than long-term rents")
    light_grid(ax, "y")
    save(fig, "q4_price_vs_rent_growth.png")


# ---------------------------------------------------------------------
# Chart 5: listings over the night limit
# ---------------------------------------------------------------------
def chart_5(df):
    df = df.copy()

    names = []
    for i in range(len(df)):
        row = df.iloc[i]
        rule = REGULATION_LABELS.get(row["regulation_type"], row["regulation_type"])
        limit = row["annual_night_limit"]
        if pd.isna(limit):
            rule_text = rule + " (no night limit)"
        else:
            rule_text = rule + " (" + str(int(limit)) + " nights/year)"
        names.append(row["neighborhood"] + "\n" + rule_text)

    total = df["total_listings"].astype(int).tolist()
    over = df["listings_over_limit"].astype(int).tolist()

    # Horizontal bars, first row on top
    names.reverse()
    total.reverse()
    over.reverse()

    positions = list(range(len(names)))
    height = 0.38
    upper = []
    lower = []
    for p in positions:
        upper.append(p + height / 2 + 0.01)
        lower.append(p - height / 2 - 0.01)

    fig, ax = new_figure()
    bars_total = ax.barh(upper, total, height, color=GRAY, label="Active listings under this rule")
    bars_over = ax.barh(lower, over, height, color=ORANGE, label="Estimated over the night limit")

    total_labels = []
    for v in total:
        total_labels.append(str(v))
    over_labels = []
    for v in over:
        over_labels.append(str(v))
    label_bars(ax, bars_total, total_labels, horizontal=True)
    label_bars(ax, bars_over, over_labels, horizontal=True)

    ax.set_yticks(positions)
    ax.set_yticklabels(names, fontsize=11)
    ax.set_xlabel("Number of listings")
    ax.set_xlim(0, max(total) * 1.25)
    ax.xaxis.set_major_locator(plt.MaxNLocator(integer=True))
    handles, labels = ax.get_legend_handles_labels()
    ax.legend(handles, labels, frameon=False, loc="lower right")
    ax.set_title("Listings that may break the local night limit")
    light_grid(ax, "x")
    fig.text(0.01, 0.045,
             "Nights booked estimated as 365 minus available days, so this may overestimate.",
             fontsize=10, color=TEXT_SOFT, style="italic")
    save(fig, "q5_night_limit.png")


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
def run_all(read_query):
    """read_query is a function: SQL text -> pandas DataFrame."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    set_style()

    chart_1(read_query(QUERY_1))
    chart_2(read_query(QUERY_2))
    chart_3(read_query(QUERY_3))
    chart_4(read_query(QUERY_4))
    chart_5(read_query(QUERY_5))

    print("Done. All charts are in the '" + OUTPUT_DIR + "' folder.")


def main():
    password = getpass.getpass("MySQL password for " + DB_USER + ": ")
    url = ("mysql+pymysql://" + DB_USER + ":" + password + "@"
           + DB_HOST + ":" + str(DB_PORT) + "/" + DB_NAME)
    engine = create_engine(url)

    def read_query(sql):
        return pd.read_sql(sql, engine)

    run_all(read_query)


if __name__ == "__main__":
    main()