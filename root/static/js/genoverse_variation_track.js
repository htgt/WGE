Genoverse.Track.Variation = Genoverse.Track.extend({
        // The basics for a variation track reading from Ensembl
        // Don't want the position property that comes with populateMenu by default

        // The $.get is asynchronous so we need to use a deferred object, resolve it on completion of atts
        // then Genoverse will do the right thing because populateMenu accepts a deferred object.
        //
    populateMenu: function ( feature ) {
        
        var deferred = $.Deferred();

        $.get("http://rest.ensembl.org/variation/" + ensembl_species + "/" + feature.id + "?content-type=application/json",
            write_menu);

        function write_menu ( data ) {
            console.log( data );
            var atts = {
                type: feature.feature_type,
                ID:   feature.id,
                alt_alleles: feature.alt_alleles,
                ambiguity: data.ambiguity || "N/A",
                consequence: feature.consequence_type,
                MAF: data.MAF || "N/A",
                evidence: data.evidence,
                class: data.var_class,
                assembly: feature.assembly_name,
                chromosome: feature.seq_region_name,
                strand: feature.strand,
                start: feature.start,
                end: feature.end
            };        
            console.log(atts);
            deferred.resolve(atts);
         }
        return( deferred );
      }
});

