(function() {
  var Query, consoleLog, inspect, operatorMap, q;
  operatorMap = {
    '=': 'eq',
    '==': 'eq',
    '>': 'gt',
    '>=': 'ge',
    '<': 'lt',
    '<=': 'le',
    '!=': 'ne'
  };
  Query = (function() {
    function Query(query, parameters) {
      var call, k, leftoverCharacters, removeParentProperty, setConjunction, term, topTerm, v;
      if (query == null) {
        query = '';
      }
      term = this;
      topTerm = term;
      if (typeof query === 'object') {
        if (Array.isArray(query)) {
          query = topTerm["in"]('id', query);
        } else if (!(query instanceof Query)) {
          for (k in query) {
            v = query[k];
            term = new Query();
            topTerm.args.push(term);
            term.name = 'eq';
            term.args = [k, v];
          }
        }
        return;
      }
      if (query.charAt(0) === '?') {
        query = query.substring(1);
      }
      if (query.indexOf('/') >= 0) {
        query = query.replace(/[\+\*\$\-:\w%\._]*\/[\+\*\$\-:\w%\._\/]*/g, function(slashed) {
          return '(' + slashed.replace(/\//g, ',') + ')';
        });
      }
      query = query.replace(/(\([\+\*\$\-:\w%\._,]+\)|[\+\*\$\-:\w%\._]*|)([<>!]?=(?:[\w]*=)?|>|<)(\([\+\*\$\-:\w%\._,]+\)|[\+\*\$\-:\w%\._]*|)/g, function(t, property, operator, value) {
        if (operator.length < 3) {
          if (!operatorMap[operator]) {
            throw new URIError('Illegal operator ' + operator);
          }
          operator = operatorMap[operator];
        } else {
          operator = operator.substring(1, operator.length - 1);
        }
        return operator + '(' + property + ',' + value + ')';
      });
      if (query.charAt(0) === '?') {
        query = query.substring(1);
      }
      call = function(newTerm) {
        term.args.push(newTerm);
        return term = newTerm;
      };
      setConjunction = function(operator) {
        if (!term.name) {
          return term.name = operator;
        } else if (term.name !== operator) {
          throw new Error('Can not mix conjunctions within a group, use parenthesis around each set of same conjuctions (& and |)');
        }
      };
      leftoverCharacters = query.replace(/(\))|([&\|,])?([\+\*\$\-:\w%\._]*)(\(?)/g, function(t, closedParen, delim, propertyOrValue, openParen) {
        var isArray, newTerm;
        if (delim) {
          if (delim === '&') {
            setConjunction('and');
          } else if (delim === '|') {
            setConjunction('or');
          }
        }
        if (openParen) {
          newTerm = new Query();
          newTerm.name = propertyOrValue;
          newTerm.parent = term;
          call(newTerm);
        } else if (closedParen) {
          isArray = !term.name;
          term = term.parent;
          if (!term) {
            throw new URIError('Closing parenthesis without an opening parenthesis');
          }
          if (isArray) {
            term.args.push(term.args.pop().args);
          }
        } else if (propertyOrValue || delim === ',') {
          term.args.push(stringToValue(propertyOrValue, parameters));
        }
        return '';
      });
      if (term.parent) {
        throw new URIError('Opening parenthesis without a closing parenthesis');
      }
      if (leftoverCharacters) {
        throw new URIError('Illegal character in query string encountered ' + leftoverCharacters);
      }
      removeParentProperty = function(obj) {
        var i, v, _len, _ref;
        if (obj != null ? obj.args : void 0) {
          delete obj.parent;
          if (obj.args.forEach) {
            obj.args.forEach(removeParentProperty);
          } else {
            _ref = obj.args;
            for (i = 0, _len = _ref.length; i < _len; i++) {
              v = _ref[i];
              removeParentProperty(obj.args[i]);
            }
          }
        }
        return obj;
      };
      removeParentProperty(topTerm);
      topTerm;
    }
    Query.prototype.stringToValue = function(string, parameters) {
      return string;
    };
    return Query;
  })();
  inspect = require('./lib/node/eyes.js').inspector({
    stream: null
  });
  consoleLog = console.log;
  console.log = function() {
    var arg, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = arguments.length; _i < _len; _i++) {
      arg = arguments[_i];
      _results.push(consoleLog(inspect(arg)));
    }
    return _results;
  };
  q = new Query('id=123');
  console.log(q);
}).call(this);
