(function() {
  'use strict';  var fetchCourses, fetchGeo, parseLocation;
  parseLocation = require('simple/remote').parseLocation;
  fetchCourses = function(referenceCurrency, next) {
    if (referenceCurrency == null) {
      referenceCurrency = 'usd';
    }
    return parseLocation("http://xurrency.com/" + (referenceCurrency.toLowerCase()) + "/feed", function(err, dom) {
      var course, temp;
      course = dom[1].children.map(function(rec) {
        var _ref, _ref2, _ref3;
        return {
          id: (_ref = rec.children[9]) != null ? _ref.children[0].data : void 0,
          value: +((_ref2 = rec.children[10]) != null ? _ref2.children[0].data : void 0),
          date: Date((_ref3 = rec.children[4]) != null ? _ref3.children[0].data : void 0)
        };
      });
      course[0].id = referenceCurrency.toUpperCase();
      course[0].value = 1;
      temp = {};
      course.forEach(function(x) {
        return temp[x.id] = x;
      });
      course = temp;
      return parseLocation('http://xurrency.com/currencies', function(err, dom) {
        var currs;
        currs = dom[1].children[1].children[0].children[1].children[0].children[4].children.slice(1);
        currs.forEach(function(rec) {
          var x, _ref;
          x = rec.children[1].children[0];
          return (_ref = course[x.attribs.href.substring(1).toUpperCase()]) != null ? _ref.name = x.children[0].data : void 0;
        });
        return next(null, course);
      });
    });
  };
  fetchGeo = function(next) {
    var geo, geoByName;
    geo = {};
    geoByName = {};
    return parseLocation('http://en.wikipedia.org/wiki/ISO_3166-1', function(err, data) {
      var fn;
      fn = function(node) {
        var _ref;
        if (node.name === 'table' && ((_ref = node.attribs) != null ? _ref["class"] : void 0) === 'wikitable sortable') {
          return node.children.slice(1).forEach(function(tr) {
            var id, _ref, _ref2, _ref3, _ref4;
            id = tr.children[1].children[0].children[0].children[0].data;
            geo[id] = {
              id: id,
              name: decodeURI(((_ref = tr.children[0].children[1]) != null ? (_ref2 = _ref.attribs) != null ? _ref2.title : void 0 : void 0) || ((_ref3 = tr.children[0].children[1].children[1]) != null ? (_ref4 = _ref3.attribs) != null ? _ref4.title : void 0 : void 0)),
              iso3: tr.children[2].children[0].children[0].data,
              code: tr.children[3].children[0].children[0].data
            };
            return geoByName[geo[id].name] = id;
          });
        } else if (node.children) {
          return node.children.forEach(fn);
        }
      };
      data.forEach(fn);
      return parseLocation('http://en.wikipedia.org/wiki/List_of_countries_by_continent_(data_file)', function(err, data) {
        fn = function(node) {
          if (node.name === 'pre') {
            return node.children[0].data.split('\n').forEach(function(x) {
              var cont, id, _ref;
              _ref = x.split(' ').slice(0, 2), cont = _ref[0], id = _ref[1];
              if (id && geo[id]) {
                return geo[id].cont = cont;
              } else if (id) {
                return console.error('NO COUNTRY', id, cont);
              }
            });
          } else if (node.children) {
            return node.children.forEach(fn);
          }
        };
        data.forEach(fn);
        return parseLocation('http://en.wikipedia.org/wiki/List_of_time_zones_by_country', function(err, data) {
          fn = function(node) {
            var _ref;
            if (node.name === 'table' && ((_ref = node.attribs) != null ? _ref["class"] : void 0) === 'wikitable sortable') {
              return node.children.slice(1).forEach(function(tr) {
                var id, name;
                name = tr.children[0].children[1].attribs.title;
                if (name.substring(0, 11).toLowerCase() === 'kingdom of ') {
                  name = name.split(' ').slice(-1);
                }
                id = geoByName[name];
                if (!geo[id]) {
                  console.error('TZ FOR NO COUNTRY', name);
                  return;
                }
                geo[id].tz = [];
                return tr.children[2].children.forEach(function(x) {
                  if (x.name === 'a' && x.attribs.title.substring(0, 3) === 'UTC') {
                    return geo[id].tz.push(x.attribs.title);
                  }
                });
              });
            } else if (node.children) {
              return node.children.forEach(fn);
            }
          };
          data.forEach(fn);
          return next(null, geo);
        });
      });
    });
  };
  module.exports = {
    fetchGeo: fetchGeo,
    fetchCourses: fetchCourses
  };
}).call(this);
