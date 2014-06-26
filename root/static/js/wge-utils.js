/*
  we need some kind of order to this...
*/

//utility function to highlight a string
//result_obj is optional, used if you want additional data in the returned result
String.prototype.match_str = function(q, result_obj) {
  //make sure the lengths are the same, technically we don't need this though we'd just truncate
  if (q.length != this.length) {
    return { "str": "error - size mismatch", "total": -1 };
  }

  var result = "";
  var total = 0;

  for (var i = 0; i < this.length; i++) {
    if (this.charCodeAt(i) ^ q.charCodeAt(i)) {
        result += "<span class='mismatch'>" + q.charAt(i) + "</span>";
        total++;
    }
    else {
        result += q.charAt(i)
    }
  }

  //blank object if user didnt provide one
  result_obj = result_obj || {};

  //var res = { "str": result, "total": total };

  result_obj.str   = result;
  result_obj.total = total;

  return result_obj;
}

var nucs = {'A':'T', 'T':'A', 'C':'G', 'G':'C', 'a':'t', 't':'a', 'c':'g', 'g':'c'};
String.prototype.revcom = function() {
  var s = '';
  //loop over string backwards, get corresponding value from nucs hash
  for (var i = this.length-1; i >= 0 ; i-- ) {
    s += nucs[this.charAt(i)] || '-';
  }

  return s;
}

String.prototype.capitalise = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
}

function create_alert(text, alert_class) {
  alert_class = alert_class || "alert-danger"; //default is error box
  //create an error alert,
  //should make it so we can actually change he class
  $(".container").prepend(
      $("<div>", { "class": "alert alert-dismissable " + alert_class })
          .append( $("<button>", { "class": "close", type: "button", 'aria-hidden': "true", html: "&times;", 'data-dismiss': "alert" }) )
          .append( $("<span>", { html: text }) )
  );
}

function close_alerts() {
  $("div.alert.alert-dismissable > .close").each(function(i,button){ button.click() });
}

// function to add a bookmarking button to the crispr and crispr pair
// popup menus in the genoverse browse view
function add_bookmark_button(menu, settings){
    $.get(settings.status_uri + "/" + settings.id,
      function (data){
        console.log(data);
        if(data.error){
          close_alerts();
          create_alert(data.error);
          return;
        }
        else{
          close_alerts();
          var button_text;
          if(data.is_bookmarked){
            button_text = 'Remove Bookmark';
          }
          else{
            button_text = 'Bookmark ' + settings.type;
          }

          // remove existing button (bookmark state may have changed)
          $('[name=' + settings.id + ']').remove();

          // add the new button
          menu.append('<button name="' + settings.id + '">' + button_text + '</button>');

          // add ajax request to button
          $('[name=' + settings.id + ']').click(function (event){
            toggle_bookmark(this, settings.bookmark_uri, settings.id, settings.type, settings.spinner, settings.bookmark_track);
          });
        }
      }
    );
}

function refresh_track(track){
  if(track){
    var genoverse = $(window)[0].genoverse;
    track.controller.resetImages();

    // clear out existing data and features for this region so they are regenerated
    track.model.dataRanges.remove({ x: genoverse.start, w: genoverse.end - genoverse.start + 1, y: 0, h: 1 });
    track.model.features.remove({ x: genoverse.start, w: genoverse.end - genoverse.start + 1, y: 0, h: 1 });

    // clear out the image_container divs
    track.controller.imgContainers.empty();

    // redraw the track
    track.controller.makeFirstImage();
  }
}

function toggle_bookmark(button, path, id, item_name, spinner, bookmark_track){
  var regexp = new RegExp("Bookmark " + item_name);
  var b = button;
  var orig_text = b.textContent;

  if(b.textContent.match(regexp)){
    //console.log("bookmarking " + item_name + " " + id);
    if(spinner){
      b.innerHTML += '<img alt="Waiting" src="' + spinner + '" height="30" width="30">';
    }
    $.get(path + "/" + id + "/add",
      function (data) {
        //console.log(data);
        if(data.error){
          close_alerts();
          create_alert(data.error);
          b.textContent = orig_text;
        }
        else{
          close_alerts();
          create_alert(data.message, "alert-success");
          b.textContent = "Remove Bookmark";
          refresh_track(bookmark_track);
        }
      }
    );
  }
  else if(b.textContent.match(/Remove Bookmark/)){
    //console.log("removing bookmark for " + item_name + " " + id);
    if(spinner){
      b.innerHTML += '<img alt="Waiting" src="' + spinner + '">';
    }
    $.get(path + "/" + id + "/remove",
      function (data) {
        //console.log(data);
        if(data.error){
          close_alerts();
          create_alert(data.error);
          b.textContent = orig_text;
        }
        else{
          close_alerts();
          create_alert(data.message, "alert-success");
          b.textContent = "Bookmark " + item_name;
          refresh_track(bookmark_track);
        }
      }
    );
  }
}

function get_ensembl_link(location, species) {
  //get ensembl species name
  var ens_species;
  switch( species ) {
    case "Mouse":
      ens_species = "Mus_Musculus";
      break;
    case "Human":
      ens_species = "Homo_sapiens";
      break;
    default:
      console.log("Invalid species");
  }

  return $("<a>", { href: "http://www.ensembl.org/" + ens_species + "/psychic?q=" + location, html: location });
}

//make a crispr object so all this type of stuff is in one place
function find_off_targets_for_pair(species, left_id, right_id) {
  return $.get(
    base_url+'api/pair_off_target_search',
    { 'left_id': left_id, 'right_id': right_id, 'species': species }
  );
}

// function find_pairs(exons) {
//   var pair_data;
//   $.get('api/pair_search', { exon_id: exons }, function(data) {
//     pair_data = data;
//   })
//   .fail(ajax_failed); //create error if its not successful

//   return pair_data;
// }

function ajax_failed(data) {
  create_alert(data.responseJSON.error);
  $("#search").button('reset');
}

//params should be a hash (a value can be an array)
//e.g. build_url("test", {"csv": 1, "exon_id": ["ENSMUSE0000005825","ENSMUSE00"]})
function build_url(url, params) {
  var encoded = [];
  for (var key in params) {
    if (! params.hasOwnProperty(key)) continue; //skip inherited values

    //make an array of length one so we don't have to duplicate code
    var val;
    if (params[key] instanceof Array)
      val = params[key];
    else
      val = [params[key]];

    for (var i = 0; i < val.length; i++)
      encoded.push(encodeURIComponent(key) + "=" + encodeURIComponent(val[i]));
  }

  //don't return ? if there's no options
  return url + (encoded.length ? "?" + encoded.join("&") : "");
}