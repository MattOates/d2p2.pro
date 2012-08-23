Get up and running:

1. Install the SUPERFAMILY MySQL database as per these instructions: http://supfam.org/SUPERFAMILY/howto_use_database.html
2. Create the "disorder" MySQL database using the schema found in: sql/database_schema.sql
3. Load the dis_assignment table with all.disrange from the d2p2.pro website: LOAD DATA LOCAL INFILE '/tmp/all.disrange' INTO TABLE dis_assignment;
4. Load the genomes and proteins in a similar manner into disorder.protein and disorder.genome.
2. Install Perl >5.10 and Mojolicious see: http://perlbrew.pl and http://mojolicio.us
3. $ morbo -l 'http://localhost:3000/' script/disdb
4. In your browser go to http://loclahost:3000/ and you should see the site up and running

Known issues:

* Currently the SVG diagrams are generated from a separate CGI script that needs to be served from another webserver such as Apache2, these URLs need to be changed in the HTML templates found in template/

* The predictor table isn't dumped on the d2p2.pro website for you to have annotations this will be changed shortly
