/*
    get_all_crisprs
    Copyright (C) 2013 Genome Research Limited

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/* Hacked together by Alex Hodgkins from a program originally written 
   by German Tischler (gt1@sanger.ac.uk) in 2013 */

/*
    Note that by default this will only print half of a genomes worth of crisprs,
    you need to switch the comparison on line 118 to get the other half (sorry)
    For human chr1-10 is 6.4gb, and 11 onwards is 4.6gb.
*/

#include <iostream>
#include <cstdlib>
#include <memory>
#include <vector>
#include <list>
#include <map>
#include <string>
#include <fstream>
#include <stdexcept>
#include <new>
#include <sstream>
#include <cstdint>
#include <cassert>

void println(std::list<char> & current, std::string & seqname, int64_t & start, int pam_right) {
    std::cout << seqname << "," << start << ","; //chr
    //display seq
    for (std::list<char>::iterator it=current.begin(); it!=current.end(); ++it) {
        std::cout << *it;
    }

    //the final 1 is the species id
    std::cout << "," << pam_right << ",1" << '\n';
}

int main(int argc, char * argv[])
{
    try
    {
        if ( argc < 1 )
        {
            std::cerr << "[U] usage: " << argv[0] << " <text>" << std::endl;
            return EXIT_FAILURE;
        }
        
        // current match end position
        int64_t seqid = -1;
        std::string seqname;
        int64_t seqpos = 0;
        int64_t patlen = 23;

        // character mapping table
        uint8_t cmap[256];
        // space table
        bool smap[256];
        // fill character mapping table
        std::fill(&cmap[0],&cmap[sizeof(cmap)/sizeof(cmap[0])],4);
        cmap['a'] = cmap['A'] = 0;
        cmap['c'] = cmap['C'] = 1;
        cmap['g'] = cmap['G'] = 2;
        cmap['t'] = cmap['T'] = 3;
        // fill space table
        std::fill(&smap[0],&smap[sizeof(cmap)/sizeof(smap[0])],0);
        for ( unsigned int i = 0; i < 256; ++i )
            if ( isspace(i) )
                smap[i] = 1;
        
        std::list<char> current (23, 'N');

        // open the text file
        std::ifstream textistr(argv[1]);
        if ( ! textistr.is_open() )
        {
            std::cerr << "[D] cannot open file " << argv[2] << std::endl;
            throw std::runtime_error("Cannot open text file");
        }
        // read text file
        //int64_t linecount = 0;
        int64_t total = 0;

        bool skip = true;
        //std::string wanted = "19";
        int64_t num_done = 0;

        while ( textistr )
        {
            //if ( ++linecount % 5000000 == 0 ) {
            //    std::cerr << "At line " << linecount << std::endl;
            //}
            // get line
            std::string line;
            std::getline(textistr,line);
            // if line is not empty
            if ( line.size() )
            {
                // start of new sequence?
                if ( line[0] == '>' )
                {
                    //switch the > to a < to get all before or after 10
                    //should add a command line option to optionally split with this
                    skip = ( ++num_done > 10 );

                    seqid++;
                    seqname = line.substr(1, line.size()-1);
                    std::string::size_type first = seqname.find(" ");

                    if ( first != std::string::npos ) 
                        seqname = seqname.substr(0, first);

                    //strip Chr if its the first 3 characters
                    if ( seqname.find("Chr") == 0 )
                        seqname = seqname.substr(3, seqname.size()-1);

                    seqpos = 0;

                    // skip = seqname.compare(wanted);

                     if ( skip )
                        std::cerr << "Skipping chromosome " << seqname << std::endl;
                     else
                        std::cerr << "Processing chromosome " << seqname << std::endl;

                    //std::cerr << "Processing chromosome " << seqname << std::endl;
                }
                else
                {
                    if ( skip )
                        continue;

                    // scan the line
                    for ( std::string::size_type i = 0; i < line.size(); ++i )
                    {
                        // next character
                        uint8_t const c = line[i];
                        
                        // if character is not white space
                        if ( ! smap[c] )
                        {
                            //remove first element and add new char to the end
                            current.pop_front();
                            current.push_back(c);

                            // if we have a full pattern length worth of text
                            if ( ++seqpos >= patlen )
                            {
                                //we add one to conform to ensembl numbering instead of bed
                                int64_t seq_start = (seqpos - patlen) + 1; 
                                //check if this is a valid crispr
                                std::list<char>::iterator start = current.begin();
                                if ( *(start) == 'C' && *(++start) == 'C' ) {
                                    total++;

                                    //last field is pam_right
                                    println(current, seqname, seq_start, 0);
                                }

                                std::list<char>::iterator end = current.end();
                                if ( *(--end) == 'G' && *(--end) == 'G' ) {
                                    total++;
                                    println(current, seqname, seq_start, 1);
                                }
                            }
                        }
                        
                    }
                }
            }
        }
        std::cerr << "Found a total of " << total << " crisprs" << std::endl;
    }
    catch(std::exception const & ex)
    {
        std::cerr << "[D] " << ex.what() << std::endl;
        return EXIT_FAILURE;
    }
}
