from sql_app import models


async def make_listing(db, city=None, city_district=None, **fields):
    """Tworzy ogłoszenie z wymaganymi rekordami powiązanymi (4 FK non-null)."""
    location = models.Location(city=city, city_district=city_district)
    building, owner, features = models.Building(), models.Owner(), models.Features()
    db.add_all([location, building, owner, features])
    await db.flush()
    listing = models.Listing(
        location_id=location.location_id,
        building_id=building.building_id,
        owner_id=owner.owner_id,
        features_id=features.features_id,
        **fields,
    )
    db.add(listing)
    await db.commit()
    return listing


async def test_read_listings_empty(client):
    response = await client.get("/listings/")

    assert response.status_code == 200
    assert response.json() == []


async def test_read_listings_returns_summary_with_location(client, db):
    await make_listing(
        db,
        city="Kraków",
        city_district="Podgórze",
        rooms=2,
        area=48.5,
        price_total_zl=650000,
        price_sqm_zl=13402,
        url="https://example.com/1",
        description_text="Opis",
    )

    response = await client.get("/listings/")

    assert response.status_code == 200
    assert response.json() == [
        {
            "listing_id": 1,
            "rooms": 2,
            "area": 48.5,
            "price_total_zl": 650000.0,
            "price_sqm_zl": 13402.0,
            "location": {"city": "Kraków", "city_district": "Podgórze"},
        }
    ]


async def test_read_listings_supports_pagination(client, db):
    for i in range(3):
        await make_listing(db, city=f"Miasto {i}")

    response = await client.get("/listings/", params={"skip": 1, "limit": 1})

    assert response.status_code == 200
    assert [item["location"]["city"] for item in response.json()] == ["Miasto 1"]


async def test_read_listings_limit_above_500_returns_422(client):
    response = await client.get("/listings/", params={"limit": 501})

    assert response.status_code == 422


async def test_read_listings_negative_skip_returns_422(client):
    response = await client.get("/listings/", params={"skip": -1})

    assert response.status_code == 422
