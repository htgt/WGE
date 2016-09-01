/*
  we need some kind of order to this...
*/

//replicate perl's "str" x 5 function
String.prototype.x = function(n) {
  var s = "";
  for ( var i = 0; i < n; i++ ) s += this;
  return s;
}

//utility function to highlight a string
//result_obj is optional, used if you want additional data in the returned result
String.prototype.match_str = function(q, result_obj) {
  //make sure the lengths are the same, technically we don't need this though we'd just truncate
  if (q.length != this.length) {
    return { "str": "error - size mismatch", "total": -1 };
  }

  var result = "";
  var total = 0;
  var pam_proximal_mm = 0;
  var mm_positions = [];

  for (var i = 0; i < this.length; i++) {
    if (this.charCodeAt(i) ^ q.charCodeAt(i)) {
        result += "<span class='mismatch'>" + q.charAt(i) + "</span>";
        total++;
        if(i > 15){
            pam_proximal_mm++;
        }
        mm_positions.push(i);
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
  result_obj.pam_proximal_mm = pam_proximal_mm;
  result_obj.mm_positions = mm_positions;

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
          if(bookmark_track){
            bookmark_track.reload();
          }
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
          if(bookmark_track){
            bookmark_track.reload();
          }
        }
      }
    );
  }
}

function get_ensembl_link(location, species) {
  //get ensembl species name
  var ens_species;
  var ens_url = "http://www.ensembl.org";
  switch( species.toLowerCase() ) {
    case "mouse":
      ens_species = "Mus_Musculus";
      break;
    case "human":
      ens_url = "http://grch37.ensembl.org";
    case "grch38":
      ens_species = "Homo_Sapiens";
      break;
    default:
      console.log("Invalid species");
  }

  return $("<a>", { href: ens_url + "/" + ens_species + "/psychic?q=" + location, html: location });
}

//make a crispr object so all this type of stuff is in one place
function find_off_targets_for_pair(species, left_id, right_id) {
  return $.get(
    base_url+'api/pair_off_target_search',
    { 'left_id': left_id, 'right_id': right_id, 'species': species }
  );
}

function find_off_targets_for_individual(species, ids) {
  if ( $.isArray(ids) )
    ids = ids.join(",");

  return $.get(
    base_url+'api/individual_off_target_search',
    { 'ids[]': ids, 'species': species }
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

//generates an object mapping amino acids to their codons
function create_aa_map() {
  var nucs = ['T', 'C', 'A', 'G'];
  var amino_acids = "FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG";

  var acid_to_codons = {};

  var x = 0; //used to keep track of which amino acid we're on
  //create all possible codons
  for ( var i = 0; i < nucs.length; i++ ) {
    for ( var j = 0; j < nucs.length; j++ ) {
      for ( var k = 0; k < nucs.length; k++ ) {
        var codon = nucs[i] + nucs[j] + nucs[k];
        var aa = amino_acids.charAt(x++);

        if ( ! acid_to_codons[aa] ) acid_to_codons[aa] = []; //nitialize empty array

        acid_to_codons[aa].push(codon);
      }
    }
  }

  return acid_to_codons;
}

function silent_mutations() {
  var acid_to_codons = create_aa_map();

  var silent_mutations = {};
  for ( var aa in acid_to_codons ) {
    if ( ! acid_to_codons.hasOwnProperty(aa) ) continue;

    var codons = acid_to_codons[aa];
    for ( var i = 0; i < codons.length; i++ ) {
      var codon = codons[i];

      //get all possible variants for this amino acid, excluding this codon
      silent_mutations[codon] = $.grep(codons, function(n) { return n != codon });
    }
  }

  acid_to_codons = {}; //don't need this any longer

  return silent_mutations;
}

function colour_species() {
  var species_colours = {
    'GRCh37':  '#55bb33',
    'GRCh38':  '#ffcc77',
    'GRCm38':  '#eeaaaa',
    'default': '#CCCCCC',
  };
    //split Human (GRCh37) into ['Human (', 'GRCh37', ')']
    $(".species_label").each(function() {
      var self = $(this);

      var m = self.text().match(/([^(]+\()([A-Za-z\d]+)(\).*)/);
      var assembly = m[2];

      var colour = species_colours[assembly] || colours['default'];

      self.html(m[1] + "<span style='color:" + colour + "'>" + assembly + "</span>" + m[3]);
    });
}
