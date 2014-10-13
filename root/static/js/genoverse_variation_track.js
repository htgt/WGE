Genoverse.Track.Variation = Genoverse.Track.extend({
        // The basics for a variation track reading from Ensembl
        // Don't want the position property that comes with populateMenu by default
    populateMenu: function( feature ) {
        delete feature.position;
        return feature;
    }
});

