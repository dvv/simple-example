function RPC(url, method, data, options){
	return $.ajax({
		type: "POST",
		url: url,
		data: JSON.stringify({
			jsonrpc: '2.0', id: 1, method: method, params: data
		}),
		processData: false,
		dataType: 'json',
		contentType: 'application/json'
	}).then(
		function(response){
			console.log('RPC', response);
		},
		function(xhr){
			console.error('ERR', arguments);
		}
	);
}

function checkRPC(response){
	ok(response.result, "RPC gave result"); ok(response.error === undefined, "RPC gave no error");
}

function checkRPCError(response){
	ok(response.result === undefined, "RPC shouldn't have given result"); ok(response.error !== undefined, "RPC should have given error");
}

asyncTest("getRoot()", function() {

RPC("/", "login", {user: 'root', pass: '123'}).then(function(data){
	module("Root");
	RPC("/", "getRoot", {}).then(function(response){
		var obj = response.result;
		test("We got user public profile", function(){
			checkRPC(response);
			equals(obj.user.id, 'root', "We got user ID");
			equals(obj.user.type, 'root', "We got user type");
			ok(obj.user.email !== undefined, "We got user email");
		});
		test("We got user authority", function(){
			ok(obj.schema, "We got schema");
			ok(obj.schema.login && obj.schema.getRoot && obj.schema.getProfile && obj.schema.setProfile, "We got profile getter/setter");
		});
		module("Affiliate");
		var id = String(Math.random()).substring(2);
		var password = String(Math.random()).substring(2);
		var user = {id: id, type: 'affiliate', rights: '', blocked: false, timezone: 'UTC+04', lang: 'en'};
		RPC("/Affiliate", "add", {id: id, password: password}).then(function(response){
			var obj = response.result;
			test("Create", function(){
				checkRPC(response);
				//console.log('AFF', obj);
				deepEqual(user, obj, "Created");
			});
			RPC("/Affiliate", "get", [id]).then(function(response){
				var obj = response.result;
				test("Get", function(){
					checkRPC(response);
					//console.log('AFF', obj);
					deepEqual(user, obj, "Fetched");
				});
				RPC("/Affiliate", "update", [[id], {blocked: true, rights: "reseller", lang: 'chti'}]).then(function(response){
					var obj = response.result;
					test("Update :: blocked: true, lang: 'chti'", function(){
						checkRPC(response);
						//console.log('AFF', obj);
						strictEqual(true, obj, "Updated");
					});
					RPC("/Affiliate", "query", ['']).then(function(response){
						var obj = response.result;
						test("Query", function(){
							checkRPC(response);
							//console.log('AFF', obj);
							_.extend(user, {blocked: true, rights: "reseller"});
							window.users = obj;
							window.user = user;
							deepEqual(user, _.detect(users,function(x){return x.id === user.id;}), "Queried, user included");
							ok(_.detect(users,function(x){return x.type === 'affiliate' && x.blocked && x.lang === 'en' && x.rights === 'reseller';}), "Checked bulk update");
						});
						RPC("/", "getProfile", []).then(function(response){
							var obj = response.result;
							test("get profile", function(){
								checkRPCError(response);
								//console.log('AFF', obj);
							});
							module('User');
							// unblock the user
							RPC("/Affiliate", "update", [[id], {blocked: false}]).then(function(response){
								var obj = response.result;
								test("Update :: blocked: false", function(){
									checkRPC(response);
								});
								RPC("/", "login", {user: id, pass: password}).then(function(response){
									var obj = response.result;
									test("Login", function(){
										checkRPC(response);
										//console.log('AFF', obj);
										//deepEqual([user], obj, "Queried");
									});
								});
							});
						});
					});
				});
			});
		});
	});
		start();
});

});