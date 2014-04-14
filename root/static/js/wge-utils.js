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
  var ots_data;
  $.get(
    base_url+'api/pair_off_target_search', 
    { 'left_id': left_id, 'right_id': right_id, 'species': species }, 
    function(data) {
      ots_data = data;
    } 
  );

  return ots_data;
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
