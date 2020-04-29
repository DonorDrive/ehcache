component extends = "mxunit.framework.TestCase" {

	function afterTests() {
		variables.manager.removeCache("mxunitTestCache");
	}

	function beforeTests() {
		try {
			variables.manager = new lib.ehcache.Manager().createFromPath(expandPath("/lib/ehcache/tests/test.xml.cfm"));
			variables.cache = variables.manager
				.addCache(name = "mxunitTestCache", copyFrom = "mxunitCache")
				.getQueryableCache(name = "mxunitTestCache");

			variables.testCache = variables.manager.getCache(name = "mxunitTestCache");

			variables.query = queryNew(
				"id, createdTimestamp, createdDate, createdTime, foo, bar, letter",
				"varchar, timestamp, date, time, integer, bit, varchar"
			);

			variables.now = now();
			for(local.i = 1; local.i <= 1000; local.i++) {
				queryAddRow(
					variables.query,
					{
						"id": (local.i == 500 ? "Šťŕĭńġ" : createUUID()),
						"bar": (!randRange(1, 3) % 2 ? local.i % 2 : javaCast("null", "")),
						"foo": local.i,
						"createdTimestamp": (!randRange(1, 3) % 2 ? variables.now : javaCast("null", "")),
						"createdDate": (!randRange(1, 3) % 2 ? variables.now : javaCast("null", "")),
						"createdTime": (!randRange(1, 3) % 2 ? variables.now : javaCast("null", "")),
						"letter": chr(64 + randRange(1, 25) + (local.i % 2 ? 32 : 0))
					}
				);
			}

			variables.queryable = new lib.sql.QueryOfQueries(variables.query).setIdentifierField("id");

			variables.cache
				.setTimeToIdleSeconds(180)
				.setQueryable(variables.queryable)
				.seedFromQueryable();
		} catch(Any e) {
			variables.exception = e;
		}
	}

	function test_containsRow() {
// debug(variables.exception); return;
		assertTrue(variables.cache.containsRow(id = variables.query.id[1]));
		assertFalse(variables.cache.containsRow(id = "boo-boo-butt"));
	}

	function test_fieldExists() {
		assertTrue(variables.cache.fieldExists("id"));
		assertFalse(variables.cache.fieldExists("asdfasfasdf"));
	}

	function test_fieldIsFilterable() {
		assertTrue(variables.cache.fieldIsFilterable("id"));
		assertFalse(variables.cache.fieldIsFilterable("asdfasfasdf"));
	}

	function test_getFieldList() {
		assertEquals(variables.queryable.getFieldList(), variables.cache.getFieldList());
	}

	function test_getFieldSQL() {
		assertEquals("", variables.cache.getFieldSQL("id"));
	}

	function test_getFieldSQLType() {
		assertEquals("varchar", variables.cache.getFieldSQLType("id"));
		assertEquals("timestamp", variables.cache.getFieldSQLType("createdTimestamp"));
		assertEquals("integer", variables.cache.getFieldSQLType("foo"));
		assertEquals("bit", variables.cache.getFieldSQLType("bar"));
	}

	function test_getRow() {
		local.compare = variables.testCache.get(variables.cache.getRowKey(argumentCollection = queryGetRow(variables.query, 1)));
		local.row = variables.cache.getRow(id = local.compare.id);

		assertEquals(local.compare, local.row);
	}

	function test_isClustered() {
		assertEquals(variables.testCache.getCache().isTerracottaClustered(), variables.cache.isClustered());
	}

	function test_putRow() {
		local.queryRow = queryGetRow(variables.query, 1);
		local.queryRow.createdTimestamp = createDateTime(1948, 12, 10, 10, 0, 0);
		variables.cache.putRow(local.queryRow);
		local.compare = variables.testCache.get(variables.cache.getRowKey(argumentCollection = local.queryRow));

		assertEquals(createDateTime(1948, 12, 10, 10, 0, 0), local.compare.createdTimestamp);
	}

	function test_removeRow() {
		local.queryRow = queryGetRow(variables.query, 1);
		local.queryRow.id = createUUID();
		variables.cache.putRow(local.queryRow);

		assertTrue(variables.cache.containsRow(id = local.queryRow.id));
		variables.cache.removeRow(id = local.queryRow.id);
		assertFalse(variables.cache.containsRow(id = local.queryRow.id));
	}

	function test_seedFromQueryable() {
		local.keyList = variables.testCache.keyList();

//		debug(local.keyList);

		assertEquals(1000, listLen(local.keyList));
	}

	function test_seedFromQueryable_overwrite() {
		variables.cache.seedFromQueryable();

		local.key = listFirst(variables.testCache.keyList());
		local.element = variables.testCache.get(local.key);
		local.element.foo = 1337;

		variables.testCache.put(local.key, local.element);

//		debug(local.element);

		variables.cache.seedFromQueryable(overwrite = true);

		local.overwriteElement = variables.testCache.get(local.key);

//		debug(local.overwriteElement);

		assertNotEquals(local.element.foo, local.overwriteElement.foo);
	}

	function test_select() {
		local.select = variables.cache.select();
//		debug(local.select);

		local.result = local.select.execute();
//		debug(local.result);

		assertEquals(1000, local.result.recordCount);
	}

	function test_select_aggregate() {
		try {
			variables.cache.select("SUM(foo)").execute();
			fail("should not be here");
		} catch(Any e) {
			assertEquals("lib.ehcache.UnsupportedOperationException", e.type);
		}
	}

	function test_select_empty() {
		local.cache = variables.manager.addCache(name = "mxunitTestEmptyCache", copyFrom = "mxunitCache")
			.getQueryableCache(name = "mxunitTestEmptyCache");

		local.cache.setQueryable(variables.queryable);

		local.select = local.cache.select();
//		debug(local.select);

		local.result = local.select.execute();
//		debug(local.result);
		assertEquals(0, local.result.recordCount);
	}

	function test_select_orderBy_DD_13345() {
		local.result = variables.cache.select().orderBy("bar DESC, foo ASC").execute(limit = 10);

		debug(local.result);
		assertEquals(10, local.result.recordCount);
	}

	function test_select_orderBy_DD_13346() {
		local.result = variables.cache.select("letter, foo").orderBy("letter ASC, foo DESC").execute();

		debug(local.result);
	}

	function test_select_orderBy_limit() {
		local.result = variables.cache.select().orderBy("foo DESC").execute(limit = 10);

		debug(local.result);
		assertEquals(10, local.result.recordCount);
		assertEquals("1000,999,998,997,996,995,994,993,992,991", valueList(local.result.foo));
	}

	function test_select_orderBy_limit_offset() {
		local.result = variables.cache.select().orderBy("foo ASC").execute(limit = 10, offset = 10);

		debug(local.result);
		assertEquals(10, local.result.recordCount);
		debug(local.result.getMetadata().getExtendedMetadata().totalRecordCount);
		assertEquals(1000, local.result.getMetadata().getExtendedMetadata().totalRecordCount);
		assertEquals("11,12,13,14,15,16,17,18,19,20", valueList(local.result.foo));
	}

	function test_select_where() {
		local.result = variables.cache.select().where("id = #variables.query.id#").execute();

//		debug(local.result);
		assertEquals(variables.query.id, local.result.id);
		assertEquals(variables.query.createdTimestamp, local.result.createdTimestamp);
		assertEquals(variables.query.createdDate, local.result.createdDate);
		assertEquals(variables.query.createdTime, local.result.createdTime);
		assertEquals(1, local.result.recordCount);
	}

	function test_select_where_compound_limit() {
		local.result = variables.cache.select().where("bar = 1 AND createdTimestamp >= '#dateTimeFormat(dateAdd("s", -10, variables.now), "yyyy-mm-dd HH:nn:ss.l")#'").execute(limit = 10);

//		debug(local.result);
//		debug(local.result.getMetadata().getExtendedMetadata());
		assertEquals(10, local.result.recordCount);
	}

	function test_select_where_in() {
		local.result = variables.cache.select("id, foo").where("id IN ('#variables.query.id[1]#', '#variables.query.id[2]#', '#variables.query.id[3]#') OR foo IN ('5', '10', '15')").execute();

//		debug(local.result);
		assertEquals("foo,id", listSort(local.result.columnList, "textnocase"));
		assertEquals("1,2,3,5,10,15", listSort(valueList(local.result.foo), "numeric"));
		assertEquals(6, local.result.recordCount);

		// test a single record
		local.result = variables.cache.select("id, foo").where("id IN ('#variables.query.id[1]#'").execute();

//		debug(local.result);
		assertEquals("foo,id", listSort(local.result.columnList, "textnocase"));
		assertEquals("1", listSort(valueList(local.result.foo), "numeric"));
		assertEquals(1, local.result.recordCount);

		// test negation of a single record
		local.result = variables.cache.select("id, foo").where("id NOT IN ('#variables.query.id[1]#'").execute();

//		debug(local.result);
		assertEquals("foo,id", listSort(local.result.columnList, "textnocase"));
		assertEquals(999, local.result.recordCount);
	}

//	function test_select_where_isnull_limit() {
//		local.result = variables.cache.select("id, foo").where("createdTimestamp IS NULL").execute(limit = 10);
//
//		debug(local.result);
//		assertEquals("foo,id", listSort(local.result.columnList, "textnocase"));
//		assertEquals(10, local.result.recordCount);
//	}

	function test_select_where_not_in() {
		local.result = variables.cache.select("id, foo").where("foo NOT IN ('5', '10', '15') AND foo < 15").execute();

		debug(local.result);
		assertEquals("foo,id", listSort(local.result.columnList, "textnocase"));
		assertEquals("1,2,3,4,6,7,8,9,11,12,13,14", listSort(valueList(local.result.foo), "numeric"));
		assertEquals(12, local.result.recordCount);
	}

	function test_select_where_DD_12824() {
		local.result = variables.cache.select().where("createdTimestamp < '#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss.l')#' AND bar = 1").execute();

		debug(local.result);
	}

	function test_select_where_DD_13660() {
		local.result = variables.cache.select("letter, foo").where("foo > 990.00").execute();

		debug(local.result);
	}

	function test_select_where_DD_13763() {
		local.where = "id LIKE '%#listFirst(lCase(variables.query.id[1]), '-')#%'";
		local.result = variables.cache.select().where(local.where).orderBy("foo ASC").execute();

		assertTrue(local.result.recordCount >= 1);

		debug(local.where);
		debug(local.result);
	}

	function test_select_where_DDMAINT_21917() {
		local.where = "id = 'Šťŕĭńġ'";
		local.result = variables.cache.select().where(local.where).execute();

		assertEquals(1, local.result.recordCount);
		assertEquals(500, local.result.foo);

		debug(local.where);
		debug(local.result);
	}

	function test_select_where_orderBy_limit() {
		local.result = variables.cache.select().where("foo <= 500").orderBy("foo DESC").execute(limit = 10);

//		debug(local.result);
		assertEquals("500,499,498,497,496,495,494,493,492,491", valueList(local.result.foo));
		assertEquals(10, local.result.recordCount);
	}

}