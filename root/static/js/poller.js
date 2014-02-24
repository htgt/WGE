// From <https://github.com/blog/467-smart-js-polling> 

(function($) {
  $.smartPoller = function(wait, poller) {
    if ($.isFunction(wait)) {
      poller = wait;
      wait = 1000;
    }

    (function startPoller() {
      setTimeout(function() {
        poller.call(this, startPoller);
      }, wait);
      wait = wait * 1.5;
    })();
  };
} )(jQuery);