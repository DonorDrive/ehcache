component accessors = "true" extends = "lib.sql.QueryableCache" {

	property name = "timeToIdleSeconds" type = "numeric";
	property name = "timeToLiveSeconds" type = "numeric";

	QueryableCache function init(required string name, string managerName) {
		variables.cache = new Cache(argumentCollection = arguments);
		variables.normalizer = createObject("java", "java.text.Normalizer");
		variables.normalizerForm = createObject("java", "java.text.Normalizer$Form").NFD;

		return this;
	}

	any function attributesFor(required any element) {
		local.indexedAttributes = createObject("java", "java.util.HashMap").init();
		local.elementValue = element.getValue();

		// we can't index this fella, (nothingtodohere)
		if(!isStruct(local.elementValue)) {
			return;
		}

		for(local.field in getQueryable().getFieldList()) {
			if(getQueryable().fieldIsFilterable(local.field)) {
				switch(getQueryable().getFieldSQLType(local.field)) {
					case "bigint":
						if(structKeyExists(local.elementValue, local.field) && isNumeric(local.elementValue[local.field])) {
							local.indexedAttributes.put(local.field, javaCast("long", local.elementValue[local.field]));
						} else {
							local.indexedAttributes.put(local.field, javaCast("long", 0));
						}
						break;
					case "bit":
						if(structKeyExists(local.elementValue, local.field) && isBoolean(local.elementValue[local.field])) {
							local.indexedAttributes.put(local.field, javaCast("boolean", local.elementValue[local.field]));
						} else {
							local.indexedAttributes.put(local.field, javaCast("boolean", false));
						}
						break;
					case "char":
						if(structKeyExists(local.elementValue, local.field) && len(local.elementValue[local.field]) > 0) {
							// lower casing ensures a case-insensitive sort
							local.indexedAttributes.put(local.field, javaCast("char", stripAccents(lCase(local.elementValue[local.field]))));
						} else {
							local.indexedAttributes.put(local.field, javaCast("char", javaCast("null", "")));
						}
						break;
					case "date":
					case "time":
					case "timestamp":
						if(structKeyExists(local.elementValue, local.field) && isDate(local.elementValue[local.field])) {
							local.indexedAttributes.put(local.field, javaCast("long", local.elementValue[local.field].getTime()));
						} else {
							local.indexedAttributes.put(local.field, javaCast("long", -1));
						}
						break;
					case "decimal":
					case "double":
					case "money":
					case "numeric":
						if(structKeyExists(local.elementValue, local.field) && isNumeric(local.elementValue[local.field])) {
							local.indexedAttributes.put(local.field, javaCast("double", local.elementValue[local.field]));
						} else {
							local.indexedAttributes.put(local.field, javaCast("double", 0));
						}
						break;
					case "float":
					case "real":
						if(structKeyExists(local.elementValue, local.field) && isNumeric(local.elementValue[local.field])) {
							local.indexedAttributes.put(local.field, javaCast("float", local.elementValue[local.field]));
						} else {
							local.indexedAttributes.put(local.field, javaCast("float", 0));
						}
						break;
					case "integer":
					case "smallint":
					case "tinyint":
						if(structKeyExists(local.elementValue, local.field) && isNumeric(local.elementValue[local.field])) {
							local.indexedAttributes.put(local.field, javaCast("int", local.elementValue[local.field]));
						} else {
							local.indexedAttributes.put(local.field, javaCast("int", 0));
						}
						break;
					default:
						if(structKeyExists(local.elementValue, local.field) && len(local.elementValue[local.field]) > 0) {
							// lower casing ensures a case-insensitive sort
							local.indexedAttributes.put(local.field, javaCast("string", stripAccents(lCase(local.elementValue[local.field]))));
						} else {
							local.indexedAttributes.put(local.field, javaCast("string", javaCast("null", "")));
						}
						break;
				};
			}
		}

		return local.indexedAttributes;
	}

	boolean function containsRow() {
		if(structKeyExists(arguments, getIdentifierField())) {
			return variables.cache.containsKey(getRowKey(argumentCollection = arguments));
		}

		return false;
	}

	query function executeSelect(required lib.sql.SelectStatement selectStatement, required numeric limit, required numeric offset) {
		if(arrayLen(arguments.selectStatement.getAggregates()) > 0) {
			throw(type = "lib.ehcache.UnsupportedOperationException", message = "Aggregates are not supported in this implementation");
		}

		local.sql = "SELECT key FROM " & variables.cache.getCache().getName();

		if(len(arguments.selectStatement.getWhereSQL()) > 0) {
			local.criteria = arguments.selectStatement.getWhereCriteria();
			local.parameters = arguments.selectStatement.getParameters();
			local.where = arguments.selectStatement.getWhereSQL();

			for(local.i = 1; local.i <= arrayLen(local.criteria); local.i++) {
				switch(local.criteria[local.i].operator) {
					case "IN":
					case "NOT IN":
						// ehcache doesn't like performing "IN" on single-element sets
						if(listLen(local.parameters[local.i].value, chr(31)) == 1) {
							local.statement = local.criteria[local.i].field & " " & (local.criteria[local.i].operator == "IN" ? "=" : "!=") & " ?";
						} else if(local.criteria[local.i].operator == "NOT IN") {
							// ehcache's query interface expects negation of the whole criteria
							local.statement = "(NOT(#local.criteria[local.i].field# IN (?)))";
						} else {
							local.statement = local.criteria[local.i].statement;
						}
						break;
					case "LIKE":
						// replace w/ case-insensitive version
						local.statement = replaceNoCase(local.criteria[local.i].statement, "LIKE", "ILIKE");
						break;
					default:
						local.statement = local.criteria[local.i].statement;
						break;
				};

				// replace the statement with our cache-friendly version
				local.where = replace(local.where, local.criteria[local.i].statement, local.statement , "one");

				local.whereValue = "";
				// in the case of "IN/NOT IN" we must format/cast each individual value appropriately
				for(local.value in listToArray(local.parameters[local.i].value, chr(31))) {
					// javaCast'ing here ensures correct value precision
					switch(local.parameters[local.i].cfsqltype) {
						case "bigint":
							local.whereValue = listAppend(local.whereValue, "(long)" & javaCast("long", local.value));
							break;
						case "bit":
							local.whereValue = listAppend(local.whereValue, "(bool)" & (local.value ? "'true'" : "'false'"));
							break;
						case "date":
						case "time":
						case "timestamp":
							local.whereValue = listAppend(local.whereValue, "(long)" & javaCast("long", parseDateTime(local.value).getTime()));
							break;
						case "decimal":
						case "double":
						case "money":
						case "numeric":
							local.whereValue = listAppend(local.whereValue, "(double)'" & javaCast("double", local.value) & "'");
							break;
						case "float":
						case "real":
							local.whereValue = listAppend(local.whereValue, "(float)'" & javaCast("float", local.value) & "'");
							break;
						case "integer":
						case "smallint":
						case "tinyint":
							local.whereValue = listAppend(local.whereValue, "(int)" & javaCast("int", local.value));
							break;
						default:
							// default to string/char
							local.value = stripAccents(local.value);

							if(local.criteria[local.i].operator == "LIKE") {
								// replacing SQL wildcards w/ ILIKE wildcards
								local.value = replace(local.value, "%", "*", "all");
								local.value = replace(local.value, "_", "?", "all");
							}

							local.whereValue = listAppend(local.whereValue, "'" & local.value & "'");
							break;
					};
				}

				// replace our placeholders w/ the cache-friendly values
				local.where = replace(local.where, "?", local.whereValue, "one");
			}

			local.sql &= " " & local.where;
		}

		if(len(arguments.selectStatement.getOrderBySQL()) > 0) {
			/*
				a known bug/workaround for incorrect sort direction of subsequent order-by fields;
				instead of a list, each clause is its own distinct ORDER BY :eyeroll:
				`ORDER BY col1 DESC, col2 ASC` becomes `ORDER BY col1 DESC ORDER BY col2 ASC`
			*/
			local.sql &= " " & replace(arguments.selectStatement.getOrderBySQL(), ",", " ORDER BY ", "all");
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

			if(arguments.offset > 0) {
				if(arguments.limit <= 0) {
					throw(type = "lib.ehcache.InvalidLimitException", message = "Limit must be furnished when offset is defined");
				}

				local.resultsArray = duplicate(local.results.range(arguments.offset, arguments.limit));
			} else if(arguments.limit > 0) {
				local.resultsArray = duplicate(local.results.range(0, arguments.limit));
			} else {
				local.resultsArray = duplicate(local.results.all());
			}

			local.resultsLength = local.results.size();
			local.results.discard();
		} catch(net.sf.ehcache.search.attribute.UnknownAttributeException e) {
			if(variables.cache.getCache().getKeysNoDuplicateCheck().size() == 0) {
				local.cacheException = true;
				// our cache is empty - set an empty resultsArray
				local.resultsArray = [];
			} else {
				rethrow;
			}
		} catch(org.terracotta.toolkit.nonstop.NonStopException e) {
			// terracotta-backed caches throw this exception during a service interruption
			local.cacheException = true;
			local.resultsArray = [];
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
			// use the underlying Ehcache method, so we can avoid some extraneous logic under load
			local.element = variables.cache.getCache().get(local.result.getKey());

			if(structKeyExists(local, "element")) {
				local.element = local.element.getObjectValue();

				local.row = {};

				for(local.column in arguments.selectStatement.getSelect()) {
					if(structKeyExists(local.element, local.column)) {
						local.row[local.column] = local.element[local.column];
					} else {
						local.row[local.column] = javaCast("null", "");
					}
				}

				queryAddRow(local.query, local.row);
			}
		}

		local.query
			.getMetadata()
				.setExtendedMetadata({
					cached: !structKeyExists(local, "cacheException"),
					engine: "ehcache",
					recordCount: arrayLen(local.resultsArray),
					totalRecordCount: (structKeyExists(local, "resultsLength") ? local.resultsLength : 0)
				});

		return local.query;
	}

	any function getRow() {
		if(structKeyExists(arguments, getIdentifierField())) {
			return variables.cache.get(getRowKey(argumentCollection = arguments));
		}
	}

	string function getRowKey() {
		local.rowKey = variables.rowKeyMask;

		local.pos = find("{", local.rowKey);

		do {
			local.end = find("}", local.rowKey, local.pos);
			local.keyArg = mid(local.rowKey, local.pos + 1, local.end - local.pos - 1);
			local.rowKey = replace(local.rowKey, "{#local.keyArg#}", REReplace(arguments[local.keyArg], "[^A-Za-z0-9]", "", "all"));
			local.pos = find("{", local.rowKey);
		} while(local.pos > 0);

		return local.rowKey;
	}

	boolean function isClustered() {
		return variables.cache.getCache().isTerracottaClustered();
	}

	void function putRow(required struct row) {
		if(structKeyExists(arguments.row, getIdentifierField())) {
			if(!structKeyExists(arguments, "timeToIdleSeconds")) {
				if(structKeyExists(variables, "timeToIdleSeconds")) {
					arguments.timeToIdleSeconds = variables.timeToIdleSeconds;
				} else {
					arguments.timeToIdleSeconds = variables.cache.getCache().getCacheConfiguration().getTimeToIdleSeconds();
				}
			}

			if(!structKeyExists(arguments, "timeToLiveSeconds")) {
				if(structKeyExists(variables, "timeToLiveSeconds")) {
					arguments.timeToLiveSeconds = variables.timeToLiveSeconds;
				} else {
					arguments.timeToLiveSeconds = variables.cache.getCache().getCacheConfiguration().getTimeToLiveSeconds();
				}
			}

			local.rowKey = getRowKey(argumentCollection = arguments.row);

			variables.cache.put(local.rowKey, arguments.row);
		}
	}

	void function removeRow() {
		variables.cache.remove(getRowKey(argumentCollection = arguments));
	}

	void function seedFromQueryable(boolean overwrite = false) {
		for(local.row in getQueryable().select().execute()) {
			local.key = getRowKey(argumentCollection = local.row);

			if(arguments.overwrite || !variables.cache.containsKey(local.key)) {
				variables.cache.put(local.key, local.row);
			}
		}
	}

	lib.sql.QueryableCache function setQueryable(required lib.sql.IQueryable queryable) {
		if(structKeyExists(variables, "queryable")) {
			throw(type = "lib.ehcache.QueryableDefinedException", message = "an IQueryable has been furnished already");
		}

		if(!variables.cache.getCache().isSearchable()) {
			throw(type = "lib.ehcache.IncompatibleCacheException", message = "This Cache has not been configured for search");
		} else if(isNull(arguments.queryable.getIdentifierField())) {
			throw(type = "lib.ehcache.MissingIdentifierFieldException", message = "No identifierField has been defined for this IQueryable");
		}

		super.setQueryable(arguments.queryable);

		if(!structKeyExists(variables, "rowKeyMask")) {
			setRowKeyMask("#getQueryable().getIdentifierField()#_{#getQueryable().getIdentifierField()#}");
		}

		try {
			local.proxy = createDynamicProxy(this, [ "net.sf.ehcache.search.attribute.DynamicAttributesExtractor" ]);
			variables.cache.getCache().registerDynamicAttributesExtractor(local.proxy);
		} catch(Any e) {
			// this fella doesn't support DynamicAttributesExtractor
		}

		// http://www.ehcache.org/apidocs/2.10.4/net/sf/ehcache/search/query/QueryManager.html
		variables.queryManager = createObject("java", "net.sf.ehcache.search.query.QueryManagerBuilder")
			.newQueryManagerBuilder()
				.addCache(variables.cache.getCache())
					.build();

		return this;
	}

	string function stripAccents(required string input) {
		/*
			what's goin' on:
			- https://memorynotfound.com/remove-accents-diacritics-from-string/
			- https://stackoverflow.com/questions/5697171/regex-what-is-incombiningdiacriticalmarks
		*/
		return variables.normalizer.normalize(javaCast("string", arguments.input), variables.normalizerForm).replaceAll("\p{InCombiningDiacriticalMarks}+", "");
	}

}