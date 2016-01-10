var _ = require('lodash'),  cloudinary = module.exports;
exports.config = require("./lib/config");
exports.utils = require("./lib/utils");

exports.url = function(public_id, options) {
  options = _.extend({}, options);
  return cloudinary.utils.url(public_id, options);
};
