define(['rql/parser', 'rql/query', 'rql/js-array'], function(RQLP, RQLQ, RQLA){
	return {
		exec: RQLA.executeQuery,
		Query: RQLQ.Query,
		parse: RQLP.parseGently
	};
});
