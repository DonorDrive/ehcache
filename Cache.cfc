component extends = "lib.util.EhcacheContainer" implements = "lib.sql.IQueryable" {

	Cache function init(required string name, string managerName) {
		return super.init(argumentCollection = arguments);
	}

	any function attributesFor(required any element) {
		local.s = createObject("java", "java.util.HashMap").init();
		local.v = element.getValue();

		// we can't index this fella, (nothingtodohere)
		if(!isStruct(local.v)) {
			return;
		}

// TODO: is this list exhaustive?
		for(local.field in variables.queryable.getFieldList()) {
			if(variables.queryable.fieldIsFilterable(local.field)) {
				switch(variables.queryable.getFieldSQLType(local.field)) {
					case "bigint":
						if(structKeyExists(local.v, local.field) && isNumeric(local.v[local.field])) {
							local.s.put(local.field, javaCast("long", local.v[local.field]));
						} else {
							local.s.put(local.field, javaCast("long", 0));
						}
						break;
					case "bit":
						if(structKeyExists(local.v, local.field) && isBoolean(local.v[local.field])) {
							local.s.put(local.field, javaCast("boolean", local.v[local.field]));
						} else {
							local.s.put(local.field, javaCast("boolean", false));
						}
						break;
					case "char":
						if(structKeyExists(local.v, local.field) && len(local.v[local.field]) > 0) {
							local.s.put(local.field, javaCast("char", local.v[local.field]));
						} else {
							local.s.put(local.field, javaCast("char", javaCast("null", "")));
						}
						break;
					case "date":
					case "time":
					case "timestamp":
						if(structKeyExists(local.v, local.field) && isDate(local.v[local.field])) {
							local.s.put(local.field, javaCast("long", local.v[local.field].getTime()));
						} else {
							local.s.put(local.field, javaCast("long", -1));
						}
						break;
					case "decimal":
					case "double":
					case "money":
					case "numeric":
						if(structKeyExists(local.v, local.field) && isNumeric(local.v[local.field])) {
							local.s.put(local.field, javaCast("double", local.v[local.field]));
						} else {
							local.s.put(local.field, javaCast("double", 0));
						}
						break;
					case "float":
					case "real":
						if(structKeyExists(local.v, local.field) && isNumeric(local.v[local.field])) {
							local.s.put(local.field, javaCast("float", local.v[local.field]));
						} else {
							local.s.put(local.field, javaCast("float", 0));
						}
						break;
					case "integer":
					case "smallint":
					case "tinyint":
						if(structKeyExists(local.v, local.field) && isNumeric(local.v[local.field])) {
							local.s.put(local.field, javaCast("int", local.v[local.field]));
						} else {
							local.s.put(local.field, javaCast("int", 0));
						}
						break;
					default:
						if(structKeyExists(local.v, local.field) && len(local.v[local.field]) > 0) {
							local.s.put(local.field, javaCast("string", local.v[local.field]));
						} else {
							local.s.put(local.field, javaCast("string", javaCast("null", "")));
						}
						break;
				};
			}
		}

		return local.s;
	}

	query function executeSelect(required lib.sql.SelectStatement selectStatement, required numeric limit, required numeric offset) {
		if(arrayLen(arguments.selectStatement.getAggregates()) > 0) {
			throw(type = "UnsupportedOperation", message = "Aggregates are not supported in this implementation");
		}

		local.sql = arguments.selectStatement.getSelectSQL() & " FROM " & getInstance().getName();

		if(len(arguments.selectStatement.getWhereSQL()) > 0) {
			local.criteria = arguments.selectStatement.getWhereCriteria();
			local.parameters = arguments.selectStatement.getParameters();
			local.where = arguments.selectStatement.getWhereSQL();

			for(local.i = 1; local.i <= arrayLen(local.criteria); local.i++) {
				switch(local.criteria[local.i].operator) {
					case "IN":
					case "NOT IN":
						// ehcache doesn't like performing "IN" on single-element sets
						if(listLen(local.parameters[local.i].value) == 1) {
							local.statement = local.criteria[local.i].field & " " & (local.criteria[local.i].operator == "IN" ? "=" : "!=") & " ?";
						} else if(local.criteria[local.i].operator == "NOT IN") {
							// ehcache's query interface expects negation of the whole criteria
							local.statement = "(NOT(#local.criteria[local.i].field# IN (?)))";
						} else {
							local.statement = local.criteria[local.i].statement;
						}
						break;
					default:
						local.statement = local.criteria[local.i].statement;
						break;
				};

				// replace the statement with our cache-friendly version
				local.where = replace(local.where, local.criteria[local.i].statement, local.statement , "one");

				local.whereValue = "";
				// in the case of "IN/NOT IN" we must format/cast each individual value appropriately
				for(local.value in local.parameters[local.i].value) {
					if(local.parameters[local.i].cfsqltype CONTAINS "char") {
						local.whereValue = listAppend(local.whereValue, "'" & local.value & "'");
					} else if(local.parameters[local.i].cfsqltype == "bit") {
						local.whereValue = listAppend(local.whereValue, "(bool)" & (local.value ? "'true'" : "'false'"));
					} else if(arrayFindNoCase([ "date", "time", "timestamp" ], local.parameters[local.i].cfsqltype) && isDate(local.value)) {
						// date/time values need to be explicitly manipulated to get the precision we need
						local.whereValue = listAppend(local.whereValue, "(long)" & javaCast("long", parseDateTime(local.value).getTime()));
					} else {
						local.whereValue = listAppend(local.whereValue, local.value);
					}
				}

				// replace our placeholders w/ the cache-friendly values
				local.where = replace(local.where, "?", local.whereValue, "one");
			}

			local.sql &= " " & local.where;
		}

		if(len(arguments.selectStatement.getOrderBySQL()) > 0) {
			local.sql &= " " & arguments.selectStatement.getOrderBySQL();
		}

		try {
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

			arguments.offset = arguments.offset - 1;
			if(arguments.offset > 0) {
				if(arguments.limit <= 0) {
					throw(type = "InvalidLimit", message = "Limit must be furnished when offset is defined");
				}

				local.resultsArray = local.results.range(arguments.offset, arguments.limit);
			} else if(arguments.limit > 0) {
				local.resultsArray = local.results.range(0, arguments.limit);
			} else {
				local.resultsArray = local.results.all();
			}
		} catch(net.sf.ehcache.search.attribute.UnknownAttributeException e) {
			if(getInstance().getKeysNoDuplicateCheck().size() == 0) {
				// our cache is empty - set an empty resultsArray
				local.resultsArray = [];
			} else {
				rethrow;
			}
		}

		// queryNew only supports a subset of the data types that queryparam does
		local.fieldSQLTypes = listReduce(
			arguments.selectStatement.getSelect(),
			function(v, i) {
				switch(getFieldSQLType(i)) {
					case "char":
						return listAppend(v, "varchar");
						break;
					case "float":
					case "money":
					case "numeric":
					case "real":
						return listAppend(v, "double");
						break;
					case "smallint":
					case "tinyint":
						return listAppend(v, "integer");
						break;
					default:
						return listAppend(v, getFieldSQLType(i));
						break;
				};
			},
			""
		);

		local.query = queryNew(arguments.selectStatement.getSelect(), local.fieldSQLTypes);

		for(local.result in local.resultsArray) {
			local.row = {};

			for(local.column in arguments.selectStatement.getSelect()) {
				local.value = local.result.getAttribute(getInstance().getSearchAttribute(local.column));

				if(structKeyExists(local, "value")) {
					switch(getFieldSQLType(local.column)) {
						case "date":
						case "time":
						case "timestamp":
							// date/time values need to be explicitly manipulated to get the precision we need
							if(local.value >= 0) {
								local.row[local.column] = createObject("java", "java.util.Date").init(local.value);
							} else {
								local.row[local.column] = javaCast("null", "");
							}
							break;
						default:
							// the rest of our data types should be coerced correctly based on the column type defined above
							local.row[local.column] = local.value;
							break;
					};
				} else {
					local.row[local.column] = javaCast("null", "");
				}
			}

			queryAddRow(local.query, local.row);
		}

		local.query
			.getMetadata()
				.setExtendedMetadata({
					cached: true,
					recordCount: arrayLen(local.resultsArray),
					totalRecordCount: (structKeyExists(local, "results") ? local.results.size() : 0)
				});

		// clean up after ourselves
		if(structKeyExists(local, "results")) {
			local.results.discard();
		}

		return local.query;
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

		for(local.row in variables.queryable.select().execute()) {
			local.key = getIdentifierField() & "_" & REReplace(local.row[getIdentifierField()], "[^A-Za-z0-9]", "", "all");

			if(!containsKey(local.key)) {
				put(local.key, local.row);
			}
		}
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