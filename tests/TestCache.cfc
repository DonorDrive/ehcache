component extends = "mxunit.framework.TestCase" {

	function afterTests() {
		variables.manager.removeCache("mxunitTestCache");
	}

	function beforeTests() {
		variables.manager = new lib.ehcache.Manager().createFromPath(expandPath("/lib/ehcache/tests/test.xml.cfm"));
		variables.cache = variables.manager.addCache(name = "mxunitTestCache", copyFrom = "mxunitCache");

		variables.query = queryNew(
			"id, createdDate, foo, bar",
			"varchar, timestamp, integer, bit"
		);

		for(local.i = 1; local.i <= 1000; local.i++) {
			queryAddRow(
				variables.query,
				{
					"id": createUUID(),
					"createdDate": now(),
					"foo": local.i,
					"bar": ( local.i % 2 )
				}
			);
		}

		variables.queryable = new lib.sql.QueryOfQueries(variables.query).setIdentifierField("id");

		variables.cache.setQueryable(variables.queryable).seedFromQueryable();
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
		assertEquals("timestamp", variables.cache.getFieldSQLType("createdDate"));
		assertEquals("integer", variables.cache.getFieldSQLType("foo"));
		assertEquals("bit", variables.cache.getFieldSQLType("bar"));
	}

	function test_getInstance() {
		debug(variables.cache.getInstance());
	}

	function test_seedFromQueryable() {
		local.keyList = variables.cache.keyList();

		debug(local.keyList);

		assertEquals(1000, listLen(local.keyList));
	}

	function test_select() {
		local.select = variables.cache.select();
		debug(local.select);

		local.result = local.select.execute();
		debug(local.result);
		assertEquals(1000, local.result.recordCount);
	}

}