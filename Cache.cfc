component extends = "lib.util.EhcacheContainer" implements = "lib.sql.IQueryable" {

	Cache function init(required string name, string managerName) {
		return super.init(argumentCollection = arguments);
	}

	any function attributesFor(required any element) {
		local.s = createObject("java", "java.util.HashMap").init();
		local.v = element.getValue();

		// ???
		if(!isStruct(local.v)) {
			return;
		}

// TODO: is this list exhaustive?
		for(local.field in variables.queryable.getFieldList()) {
			if(structKeyExists(local.v, local.field) && variables.queryable.fieldIsFilterable(local.field)) {
				switch(variables.queryable.getFieldSQLType(local.field)) {
					case "bigint,date,time,timestamp":
						if(isNumeric(local.v[local.field]) || isDate(local.v[local.field])) {
							local.s.put(local.field, javaCast("long", local.v[local.field]));
						}
						break;
					case "char":
						if(len(local.v[local.field]) > 0) {
							local.s.put(local.field, javaCast("char", local.v[local.field]));
						}
						break;
					case "bit":
						if(isBoolean(local.v[local.field])) {
							local.s.put(local.field, javaCast("boolean", local.v[local.field]));
						}
						break;
					case "decimal,double,money,numeric":
						if(isNumeric(local.v[local.field])) {
							local.s.put(local.field, javaCast("double", local.v[local.field]));
						}
						break;
					case "float,real":
						if(isNumeric(local.v[local.field])) {
							local.s.put(local.field, javaCast("float", local.v[local.field]));
						}
						break;
					case "integer,smallint,tinyint":
						if(isNumeric(local.v[local.field])) {
							local.s.put(local.field, javaCast("int", local.v[local.field]));
						}
						break;
					default:
						if(len(local.v[local.field]) > 0) {
							local.s.put(local.field, javaCast("string", local.v[local.field]));
						}
						break;
				};
			}

			if(!local.s.containsKey(local.field)) {
				local.s.put(local.field, javaCast("null", ""));
			}
		}

		return local.s;
	}

	query function executeSelect(required lib.sql.SelectStatement selectStatement, required numeric limit, required numeric offset) {
		local.sql = arguments.selectStatement.getSelectSQL() & " FROM " & getInstance().getName();

		if(len(arguments.selectStatement.getWhereSQL()) > 0) {
// TODO
		}

		if(len(arguments.selectStatement.getOrderBySQL()) > 0) {
			local.sql &= " " & arguments.selectStatement.getOrderBySQL();
		}

		if(arguments.limit > 0) {
			local.executionHints = createObject("java", "net.sf.ehcache.search.ExecutionHints").setResultBatchSize(arguments.limit);

			local.results = variables.queryManager
				.createQuery(local.sql)
					.end()
						.execute(local.executionHints);
		} else {
			local.results = variables.queryManager
				.createQuery(local.sql)
					.end()
						.execute();
		}

		if(arguments.offset > 1) {
			if(arguments.limit <= 0) {
				throw(type = "InvalidLimit", message = "Limit must be furnished when offset is defined");
			}
			local.resultsArray = local.results.range(arguments.offset, arguments.limit);
		} else {
			local.resultsArray = local.results.all();
		}

		local.fieldSQLTypes = listReduce(
			arguments.selectStatement.getSelect(),
			function(v, i) {
				return listAppend(v, getFieldSQLType(i));
			},
			""
		);

// TODO: enforce column type
		local.query = queryNew(arguments.selectStatement.getSelect()); //local.fieldSQLTypes

		for(local.result in local.resultsArray) {
			local.row = {};

			for(local.column in arguments.selectStatement.getSelect()) {
// TODO: alter for type consistency
				local.row[local.column] = local.result.getAttribute(getInstance().getSearchAttribute(local.column));
			}

			queryAddRow(local.query, local.row);
		}

		// clean up after ourselves
		local.results.discard();

		return local.query;


/*
<cfset query = server.qm.createQuery(sql) />
<cfset q = query.includeValues().end().execute() />
<cfset r = q.all() />
*/



/*
		var orderBySQL = arguments.selectStatement.getOrderBySQL();
		var parameters = arguments.selectStatement.getParameters();
		var selectSQL = arguments.selectStatement.getSelectSQL();
		var whereSQL = arguments.selectStatement.getWhereSQL();

		// format our incoming SQL to circumvent QoQ's case-sensitivity
		if(parameters.len() > 0) {
			for(local.i = 1; local.i <= parameters.len(); local.i++) {
				if(parameters[local.i].cfsqltype CONTAINS "char") {
					parameters[local.i].value = lCase(parameters[local.i].value);
				}
			}

			for(local.i in arguments.selectStatement.getWhereCriteria()) {
				if(getFieldSQLType(local.i.field) CONTAINS "char") {
					local.formattedClause = local.i.statement.replaceNoCase(local.i.field, local.i.field & " IS NOT NULL AND LOWER(" & local.i.field & ")");
					whereSQL = replaceNoCase(whereSQL, local.i.statement, "(" & local.formattedClause & ")", "one");
				}
			}
		}

		if(orderBySQL.len() > 0) {
			for(local.i in arguments.selectStatement.getOrderCriteria()) {
				local.field = listFirst(local.i, " ").trim();
				// QoQ cant do calculated values inside ORDER BY - only as part of the SELECT
				if(getFieldSQLType(local.field) CONTAINS "char") {
					if(!findNoCase("_order_" & local.field, selectSQL)) {
						selectSQL = listAppend(selectSQL, "LOWER(" & local.field & ") AS _order_" & local.field);
					}

					local.formattedClause = "_order_" & local.field & " " & listLast(local.i, " ");
					orderBySQL = replace(orderBySQL, local.i, local.formattedClause);
				}
			}
		}

		var result = queryExecute(
			selectSQL & " FROM query " & whereSQL & " " & orderBySQL,
			parameters,
			{ dbtype: "query" }
		);

		if(findNoCase("_order_", result.columnList)) {
			result = queryExecute(
				"SELECT #arguments.selectStatement.getSelect()# FROM result",
				[],
				{ dbtype: "query" }
			);
		}

		// at this point, we know our working record count
		var totalRecordCount = result.recordCount;

		// result pagination, if necessary (this uses the underlying (undocumented) removeRows method so we don't need to run additional QoQ - IT IS ZERO-BASED)
		if(arguments.offset > totalRecordCount) {
			result.removeRows(0, totalRecordCount);
		} else if(arguments.limit >= 0 || arguments.offset > 1) {
			// default limit to the record count of the query
			arguments.limit = (arguments.limit >= 0 && arguments.limit < totalRecordCount) ? arguments.limit : totalRecordCount;

			var startRow = (arguments.offset - 1) + arguments.limit;

			// remove from the end of the query first
			if(startRow < totalRecordCount) {
				result.removeRows(startRow, totalRecordCount - startRow);
			}

			// then remove from the front
			if(arguments.offset - 1 > 0) {
				result.removeRows(0, arguments.offset - 1);
			}
		}

		result
			.getMetadata()
				.setExtendedMetadata({
					cached: true,
					recordCount: result.recordCount,
					totalRecordCount: totalRecordCount
				});

		return result;
*/
	}

	boolean function fieldExists(required string fieldName) {
		queryableCheck();

		return variables.queryable.fieldExists(arguments.fieldName) && variables.queryable.fieldIsFilterable(arguments.fieldName);
	}

	boolean function fieldIsFilterable(required string fieldName) {
		queryableCheck();

		return variables.queryable.fieldIsFilterable(arguments.fieldName);
	}

	string function getFieldList() {
		queryableCheck();

		return listReduce(
			variables.queryable.getFieldList(),
			function(v, i) {
				if(variables.queryable.fieldIsFilterable(i)) {
					v = listAppend(v, i);
				}

				return v;
			},
			""
		);
	}

	string function getFieldSQL(required string fieldName) {
		queryableCheck();

		return "";
	}

	string function getFieldSQLType(required string fieldName) {
		queryableCheck();

		return variables.queryable.getFieldSQLType(arguments.fieldName);
	}

	string function getIdentifierField() {
		return variables.queryable.getIdentifierField();
	}

	any function getInstance() {
		return super.getCache();
	}

	private function queryableCheck() {
		if(!structKeyExists(variables, "queryable")) {
			throw(type = "MissingQueryable", message = "A Queryable implementation must be furnished before search operations are permitted");
		}
	}

	void function seedFromQueryable() {
		queryableCheck();

		queryEach(
			variables.queryable.select().execute(),
			function(row) {
				local.key = getIdentifierField() & "_" & REReplace(row[getIdentifierField()], "[^A-Za-z0-9]", "", "all");

				put(local.key, row);
			}
		);
	}

	lib.sql.SelectStatement function select(string fieldList = "*") {
		queryableCheck();

		return new lib.sql.SelectStatement(this).select(arguments.fieldList);
	}

	Cache function setQueryable(required lib.sql.IQueryable queryable) {
		if(!getInstance().isSearchable()) {
			throw(type = "IncompatibleCache", message = "This Cache has not been configured for search");
		} else if(isNull(arguments.queryable.getIdentifierField())) {
			throw(type = "MissingIdentifierField", message = "No identifierField has been defined for this IQueryable");
		}

		variables.queryable = arguments.queryable;

		try {
			local.proxy = createDynamicProxy(this, [ "net.sf.ehcache.search.attribute.DynamicAttributesExtractor" ]);
			getInstance().registerDynamicAttributesExtractor(local.proxy);
		} catch(Any e) {
			// this fella doesn't support DynamicAttributesExtractor
		}

		// http://www.ehcache.org/apidocs/2.10.4/net/sf/ehcache/search/query/QueryManager.html
		variables.queryManager = createObject("java", "net.sf.ehcache.search.query.QueryManagerBuilder")
			.newQueryManagerBuilder()
				.addCache(getInstance())
					.build();

		return this;
	}

}