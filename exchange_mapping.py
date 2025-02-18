"""
exchange_mapping.py

Loads exchange mapping data from a local JSON file.
"""

import json
import os

# Assuming exchanges.json is in the same directory as this module.
FILE_PATH = os.path.join(os.path.dirname(__file__), "exchanges.json")

def load_exchange_mapping():
    with open(FILE_PATH, "r") as f:
        data = json.load(f)
    mapping = {}
    for item in data.get("results", []):
        mapping[item["id"]] = item.get("name", f"ID {item['id']}")
    return mapping

EXCHANGE_MAPPING = load_exchange_mapping()