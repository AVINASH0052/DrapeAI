"""Demo wardrobe seeder. Pre-tagged items for new users to explore the app."""

import logging

from app.database.pool import get_pool
from app.database.queries.items import insert_item

logger = logging.getLogger(__name__)

DEMO_ITEMS = [
    {"image_key": "demo/navy_polo.png", "category": "top", "sub_category": "polo", "primary_color": "navy", "pattern": "solid", "fabric": "cotton", "formality": 3, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/white_shirt.png", "category": "top", "sub_category": "shirt", "primary_color": "white", "pattern": "solid", "fabric": "cotton", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/black_tshirt.png", "category": "top", "sub_category": "t_shirt", "primary_color": "black", "pattern": "solid", "fabric": "cotton", "formality": 1, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/maroon_kurta.png", "category": "ethnic", "sub_category": "kurta", "primary_color": "maroon", "pattern": "embroidered", "fabric": "silk", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": True},
    {"image_key": "demo/olive_jacket.png", "category": "outerwear", "sub_category": "jacket", "primary_color": "olive", "pattern": "solid", "fabric": "cotton", "formality": 3, "season_tags": ["winter"], "ethnic_flag": False},
    {"image_key": "demo/beige_chinos.png", "category": "bottom", "sub_category": "chinos", "primary_color": "beige", "pattern": "solid", "fabric": "cotton", "formality": 3, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/blue_jeans.png", "category": "bottom", "sub_category": "jeans", "primary_color": "blue", "pattern": "solid", "fabric": "denim", "formality": 2, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/grey_trousers.png", "category": "bottom", "sub_category": "trousers", "primary_color": "grey", "pattern": "solid", "fabric": "polyester", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/black_shorts.png", "category": "bottom", "sub_category": "shorts", "primary_color": "black", "pattern": "solid", "fabric": "cotton", "formality": 1, "season_tags": ["summer"], "ethnic_flag": False},
    {"image_key": "demo/white_sneakers.png", "category": "footwear", "sub_category": "sneakers", "primary_color": "white", "pattern": "solid", "fabric": "synthetic", "formality": 2, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/brown_loafers.png", "category": "footwear", "sub_category": "loafers", "primary_color": "brown", "pattern": "solid", "fabric": "leather", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/kolhapuri.png", "category": "footwear", "sub_category": "kolhapuri", "primary_color": "brown", "pattern": "solid", "fabric": "leather", "formality": 3, "season_tags": ["summer"], "ethnic_flag": True},
    {"image_key": "demo/nehru_jacket.png", "category": "ethnic", "sub_category": "nehru_jacket", "primary_color": "cream", "pattern": "solid", "fabric": "linen", "formality": 4, "season_tags": ["all_season"], "ethnic_flag": True},
    {"image_key": "demo/watch.png", "category": "accessory", "sub_category": "watch", "primary_color": "silver", "pattern": "solid", "fabric": "metal", "formality": 3, "season_tags": ["all_season"], "ethnic_flag": False},
    {"image_key": "demo/sunglasses.png", "category": "accessory", "sub_category": "sunglasses", "primary_color": "black", "pattern": "solid", "fabric": "plastic", "formality": 2, "season_tags": ["summer"], "ethnic_flag": False},
]

DEMO_USER_ID = "demo-user"


async def seed_demo_wardrobe() -> int:
    """Seed demo wardrobe items. Returns count of items created."""
    pool = await get_pool()
    count = 0
    async with pool.acquire() as conn:
        existing = await conn.fetchval(
            "SELECT COUNT(*) FROM items WHERE user_id = $1", DEMO_USER_ID
        )
        if existing > 0:
            logger.info(f"Demo wardrobe already seeded ({existing} items)")
            return existing

        for demo in DEMO_ITEMS:
            tags = {k: v for k, v in demo.items() if k != "image_key"}
            tags["confidence"] = 1.0
            tags["style_tags"] = []
            tags["secondary_colors"] = []
            await insert_item(conn, DEMO_USER_ID, demo["image_key"], tags)
            count += 1

    logger.info(f"Seeded {count} demo wardrobe items")
    return count
