'use strict';var fetchExchangeRates, parseLocation, sources;
var __hasProp = Object.prototype.hasOwnProperty;
parseLocation = require('simple/remote').parseLocation;
sources = {};
sources.who = function(referenceCurrency, next) {
  if (referenceCurrency == null) {
    referenceCurrency = 'usd';
  }
  return parseLocation('http://whoyougle.com/money/list', function(err, dom) {
    var fn;
    fn = function(node) {
      var base, course, k, v, _ref, _ref2;
      course = {};
      if (node.name === 'table' && ((_ref = node.attribs) != null ? _ref.id : void 0) === 'DataTable') {
        node.children[1].children.forEach(function(tr) {
          var rec, _ref, _ref2;
          rec = {
            id: tr.children[3].children[0].data,
            name: ((_ref = tr.children[0].children[0].children) != null ? _ref[0].data : void 0) || tr.children[0].children[0].data
          };
          if ((_ref2 = tr.children[5].children) != null ? _ref2[0].data : void 0) {
            rec.value = +tr.children[5].children[0].data;
          }
          return course[rec.id] = rec;
        });
        course.GBP.value = 1;
        base = ((_ref2 = course[referenceCurrency.toUpperCase()]) != null ? _ref2.value : void 0) || 1;
        for (k in course) {
          if (!__hasProp.call(course, k)) continue;
          v = course[k];
          course[k] = {
            id: k,
            name: v.name
          };
          if (v.value) {
            course[k].value = base / v.value;
          }
        }
        return next(null, course);
      } else if (node.children) {
        return node.children.forEach(fn);
      }
    };
    return dom.forEach(fn);
  });
};
sources.xur = function(referenceCurrency, next) {
  if (referenceCurrency == null) {
    referenceCurrency = 'usd';
  }
  return parseLocation("http://xurrency.com/" + (referenceCurrency.toLowerCase()) + "/feed", function(err, dom) {
    var course, temp;
    course = dom[1].children.map(function(rec) {
      var _ref, _ref2;
      return {
        id: (_ref = rec.children[9]) != null ? _ref.children[0].data : void 0,
        value: +((_ref2 = rec.children[10]) != null ? _ref2.children[0].data : void 0)
      };
    });
    course[0].id = referenceCurrency.toUpperCase();
    course[0].value = 1;
    temp = {};
    course.forEach(function(x) {
      return temp[x.id] = x;
    });
    course = temp;
    return next(null, course);
  });
};
sources["for"] = function(referenceCurrency, next) {
  if (referenceCurrency == null) {
    referenceCurrency = 'usd';
  }
  return parseLocation("http://www.forexrate.co.uk/ExchangeRates/" + (referenceCurrency.toUpperCase()) + ".html", function(err, dom) {
    var course;
    course = {};
    dom[1].children[1].children[0].children[2].children[5].children.slice(2).forEach(function(rec) {
      var date, id, _ref;
      if (rec.type === 'tag' && rec.name === 'tr') {
        id = (_ref = rec.children[1].children[0].attribs) != null ? _ref.href.substr(15, 3) : void 0;
        date = rec.children[3].children[0].data.trim();
        return course[id] = {
          id: id,
          value: +rec.children[2].children[0].data.trim().replace(/,/g, '')
        };
      }
    });
    return next(null, course);
  });
};
sources.cbr = function(referenceCurrency, next) {
  var date, dreq, mreq, yreq;
  if (referenceCurrency == null) {
    referenceCurrency = 'usd';
  }
  date = (new Date()).toJSON().substr(0, 10);
  mreq = date.substr(5, 2);
  yreq = date.substr(0, 4);
  dreq = date.substr(8, 2) + '%2E' + mreq + '%2E' + yreq;
  return parseLocation("http://cbr.ru/currency_base/D_print.aspx?date_req=" + dreq, function(err, dom) {
    var fn;
    fn = function(node) {
      var base, course, k, v, _ref;
      if (node.name === 'table' && ((_ref = node.attribs) != null ? _ref["class"] : void 0) === 'CBRTBL') {
        course = {
          RUB: 1
        };
        node.children.slice(1).forEach(function(tr) {
          var value;
          value = +tr.children[2].children[0].data / +tr.children[4].children[0].data.replace(/,/g, '.');
          return course[tr.children[1].children[0].data.trim().replace(/&nbsp;/g, '')] = value;
        });
        base = course[referenceCurrency.toUpperCase()] || 1;
        for (k in course) {
          if (!__hasProp.call(course, k)) continue;
          v = course[k];
          course[k] = {
            id: k,
            value: v / base
          };
        }
        return next(null, course);
      } else if (node.children) {
        return node.children.forEach(fn);
      }
    };
    return dom.forEach(fn);
  });
};
sources.ecb = function(referenceCurrency, next) {
  if (referenceCurrency == null) {
    referenceCurrency = 'usd';
  }
  return parseLocation("http://www.ecb.int/stats/eurofxref/eurofxref-daily.xml", function(err, dom) {
    var base, course, k, v;
    course = {
      EUR: 1
    };
    dom[1].children[2].children[0].children.forEach(function(tr) {
      return course[tr.attribs.currency] = +tr.attribs.rate;
    });
    base = course[referenceCurrency.toUpperCase()] || 1;
    for (k in course) {
      if (!__hasProp.call(course, k)) continue;
      v = course[k];
      course[k] = {
        id: k,
        value: v / base
      };
    }
    return next(err, course);
  });
};
fetchExchangeRates = function(referenceCurrency, next) {
  var arr, course, narr;
  if (referenceCurrency == null) {
    referenceCurrency = 'usd';
  }
  course = {};
  arr = Object.keys(sources);
  narr = arr.length;
  return arr.forEach(function(source) {
    sources[source](referenceCurrency, function(err, data) {
      var k, v;
      if (!err) {
        for (k in data) {
          if (!__hasProp.call(data, k)) continue;
          v = data[k];
          if (!course[k]) {
            course[k] = {
              id: k,
              value: {}
            };
          }
          if (v.name) {
            course[k].name = v.name;
          }
          if (v.value) {
            course[k].value[source] = v.value;
          }
        }
      }
      narr -= 1;
      if (!narr) {
        return next(null, course);
      }
    });
  });
};
module.exports = {
  fetchExchangeRates: fetchExchangeRates
};