/**
 * Tests for {@link PointInPolygonImpl}.
 */
@IsTest(IsParallel=true)
private class PointInPolygonImplTest {
  private static final PointInPolygonImpl SERVICE = new PointInPolygonImpl();

  private static final List<List<Decimal>> SQUARE = new List<List<Decimal>>{
    new List<Decimal>{ 0, 0 },
    new List<Decimal>{ 10, 0 },
    new List<Decimal>{ 10, 10 },
    new List<Decimal>{ 0, 10 },
    new List<Decimal>{ 0, 0 }
  };

  @IsTest
  private static void isInside_strictlyInsideSquare_returnsTrue() {
    Boolean result = SERVICE.isInside(5, 5, SQUARE);

    Assert.isTrue(result, 'Center point (5,5) should be inside the square');
  }

  @IsTest
  private static void isInside_strictlyOutsideSquare_returnsFalse() {
    Boolean result = SERVICE.isInside(15, 15, SQUARE);

    Assert.isFalse(result, 'Point well outside the square should be outside');
  }

  @IsTest
  private static void isInside_pointAtVertexY_outsideRing_returnsFalse() {
    // Point at the same latitude as two top vertices, but well to the west of
    // the ring. Verifies the algorithm handles ties at vertex y deterministically.
    Boolean result = SERVICE.isInside(10, -5, SQUARE);

    Assert.isFalse(result, 'Point at vertex y but outside the ring should be outside');
  }

  @IsTest
  private static void isInside_pointOnTopHorizontalEdge_returnsFalse() {
    // Documents the deterministic asymmetry of ray-casting at horizontal
    // boundaries — a point sitting exactly on the top edge of a square reads
    // as outside. Real geocoded coordinates won't land exactly on an edge,
    // so this is acceptable.
    Boolean result = SERVICE.isInside(10, 5, SQUARE);

    Assert.isFalse(result, 'Point on the top edge reads as outside');
  }

  @IsTest
  private static void isInside_nonConvexPolygon_separatesInsideFromNotch() {
    // L-shape covering the bottom half (y<=5) entirely and the upper-left
    // quarter (x<=5, y>5). The upper-right quarter (x>5, y>5) is the notch.
    List<List<Decimal>> lShape = new List<List<Decimal>>{
      new List<Decimal>{ 0, 0 },
      new List<Decimal>{ 10, 0 },
      new List<Decimal>{ 10, 5 },
      new List<Decimal>{ 5, 5 },
      new List<Decimal>{ 5, 10 },
      new List<Decimal>{ 0, 10 },
      new List<Decimal>{ 0, 0 }
    };

    // Signature: isInside(lat, lng, ring). Vertices: [lng, lat].
    Assert.isTrue(SERVICE.isInside(2, 2, lShape), '(lat=2,lng=2) is in the L bottom block');
    Assert.isTrue(SERVICE.isInside(2, 8, lShape), '(lat=2,lng=8) is in the L bottom block');
    Assert.isTrue(SERVICE.isInside(8, 2, lShape), '(lat=8,lng=2) is in the L upper-left arm');
    Assert.isTrue(SERVICE.isInside(8, 4, lShape), '(lat=8,lng=4) is in the L upper-left arm');
    Assert.isFalse(SERVICE.isInside(8, 8, lShape), '(lat=8,lng=8) is in the L notch (outside)');
  }

  @IsTest
  private static void isInside_realWorldNYCCoordinates_returnsTrueInsidePolygon() {
    // Tiny test box around the Times Square area (~40.758, -73.985).
    // Inner list shape: [lng, lat] per the GeoJSON convention used by WS1.
    List<List<Decimal>> nycBox = new List<List<Decimal>>{
      new List<Decimal>{ -73.99, 40.75 },
      new List<Decimal>{ -73.98, 40.75 },
      new List<Decimal>{ -73.98, 40.76 },
      new List<Decimal>{ -73.99, 40.76 },
      new List<Decimal>{ -73.99, 40.75 }
    };

    Boolean result = SERVICE.isInside(40.758, -73.985, nycBox);

    Assert.isTrue(result, 'Times Square coordinates should be inside the test polygon');
  }

  @IsTest
  private static void isInside_polygonNearAntimeridian_returnsExpectedAnswer() {
    // Defensive — NYC doesn't span the antimeridian, but the util is reusable.
    // This test confirms the algorithm doesn't crash on extreme longitudes.
    List<List<Decimal>> ring = new List<List<Decimal>>{
      new List<Decimal>{ -179, -1 },
      new List<Decimal>{ -178, -1 },
      new List<Decimal>{ -178, 1 },
      new List<Decimal>{ -179, 1 },
      new List<Decimal>{ -179, -1 }
    };

    Assert.isTrue(SERVICE.isInside(0, -178.5, ring), 'Center of the ring is inside');
    Assert.isFalse(SERVICE.isInside(0, 0, ring), 'Origin is far outside this ring');
  }

  @IsTest
  private static void isInside_emptyRing_returnsFalse() {
    Boolean result = SERVICE.isInside(5, 5, new List<List<Decimal>>());

    Assert.isFalse(result, 'Empty ring cannot enclose area');
  }

  @IsTest
  private static void isInside_singleVertexRing_returnsFalse() {
    List<List<Decimal>> ring = new List<List<Decimal>>{ new List<Decimal>{ 0, 0 } };

    Boolean result = SERVICE.isInside(0, 0, ring);

    Assert.isFalse(result, 'Single vertex cannot enclose area');
  }

  @IsTest
  private static void isInside_twoVertexRing_returnsFalse() {
    List<List<Decimal>> ring = new List<List<Decimal>>{
      new List<Decimal>{ 0, 0 },
      new List<Decimal>{ 10, 10 }
    };

    Boolean result = SERVICE.isInside(5, 5, ring);

    Assert.isFalse(result, 'Two vertices cannot enclose area');
  }

  @IsTest
  private static void isInside_nullLat_throwsIllegalArgumentException() {
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      SERVICE.isInside(null, 5, SQUARE);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void isInside_nullLng_throwsIllegalArgumentException() {
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      SERVICE.isInside(5, null, SQUARE);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void isInside_nullRing_throwsIllegalArgumentException() {
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      SERVICE.isInside(5, 5, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
}