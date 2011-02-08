node-xml2js-expat
==

Description
--
Simple XML to JavaScript object converter.  Uses [node-expat](https://github.com/astro/node-expat).  Install with [npm](http://github.com/isaacs/npm) :)
See the tests for examples until docs are written.
Note:  If you're looking for a full DOM parser, you probably want [JSDom](http://github.com/tmpvar/jsdom).

Simple usage
--

    var sys = require('sys'),
        fs = require('fs'),
        xml2js = require('xml2js-expat');

    var parser = new xml2js.Parser();
    parser.addListener('end', function(result, error) {
        if (!error) {
            console.log(sys.inspect(result));
        }
        else {
            console.error(error);
        }
        console.log('Done.');
    });
    fs.readFile(__dirname + '/foo.xml', function(err, data) {
        if (parser.parseString(data)) {
          console.log('xml2js: successfully parsed file.');
        }
        else {
          console.error('xml2js: parse error: "%s"', parser.getError());
        }
    });
