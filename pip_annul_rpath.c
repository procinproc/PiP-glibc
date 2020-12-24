/*
 * $PIP_license: <Simplified BSD License>
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 *     Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 * 
 *     Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 * $
 * $RIKEN_copyright: Riken Center for Computational Sceience (R-CCS),
 * System Software Development Team, 2016-2020
 * $
 * $PIP_VERSION: Version 2.0.0$
 *
 * $Author: Atsushi Hori (R-CCS) mailto: ahori@riken.jp or ahori@me.com
 * $
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <elf.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <error.h>
#include <errno.h>

static void read_elf64_header( int fd, Elf64_Ehdr *ehdr ) {
  if( read( fd, ehdr, sizeof(Elf64_Ehdr) ) != sizeof(Elf64_Ehdr) ) {
    fprintf( stderr, "Unable to read\n" );
    exit( 1 );
  } else if( ehdr->e_ident[EI_MAG0] != ELFMAG0 ||
	     ehdr->e_ident[EI_MAG1] != ELFMAG1 ||
	     ehdr->e_ident[EI_MAG2] != ELFMAG2 ||
	     ehdr->e_ident[EI_MAG3] != ELFMAG3 ) {
    fprintf( stderr, "Not an ELF\n" );
    exit( 1 );
  } else if( ehdr->e_ident[EI_CLASS] != ELFCLASS64 ) {
    fprintf( stderr, "32bit class is not supported\n" );
    exit( 1 );
  }
}

static void
read_elf64_section_header( int fd, int nth, Elf64_Ehdr *ehdr, Elf64_Shdr *shdr ) {
  off_t off = ehdr->e_shoff + ( ehdr->e_shentsize * nth );
  if( pread( fd, shdr, sizeof(Elf64_Shdr), off ) != sizeof(Elf64_Shdr) ) {
    fprintf( stderr, "Unable to read section header\n" );
    exit( 1 );
  }
#ifdef DEBUG
  printf( "[%d] Type:%d  Name:%d  Link:%d\n",
	  nth, (int) shdr->sh_type, (int) shdr->sh_name, (int) shdr->sh_link );
#endif
}

static void
write_elf64_section_header( int fd, int nth, Elf64_Ehdr *ehdr, Elf64_Shdr *shdr ) {
  off_t off = ehdr->e_shoff + ( ehdr->e_shentsize * nth );
  if( pwrite( fd, shdr, sizeof(Elf64_Shdr), off ) != sizeof(Elf64_Shdr) ) {
    fprintf( stderr, "Unable to write section header\n" );
    exit( 1 );
  }
#ifdef DEBUG
  printf( "[%d] Type:%d  Name:%d  Link:%d\n",
	  nth, (int) shdr->sh_type, (int) shdr->sh_name, (int) shdr->sh_link );
#endif
}

void read_elf64_dynamic_section( int fd, off_t offset, size_t size, Elf64_Dyn *dyns ) {
  if( pread( fd, dyns, size, offset ) != size ) {
    fprintf( stderr, "Unable to read dynamic section\n" );
    exit( 1 );
  }
}

void write_elf64_dynamic_section( int fd, off_t offset, size_t size, Elf64_Dyn *dyns ) {
  if( pwrite( fd, dyns, size, offset ) != size ) {
    fprintf( stderr, "Unable to write dynamic section\n" );
    exit( 1 );
  }
}

static void rm_rpath( char *path ) {
  Elf64_Ehdr 	ehdr;
  Elf64_Shdr	shdr;
  Elf64_Dyn	*dyns;
  int		fd, i, j, k, n, m;

  if( ( fd = open( path, O_RDWR ) ) < 0 ) {
    fprintf( stderr, "'%s': open() fails (%s)\n", path, strerror( errno ) );
    exit( 1 );
  }
  read_elf64_header( fd, &ehdr );
  for( i=0; i<ehdr.e_shnum; i++ ) {
    read_elf64_section_header( fd, i, &ehdr, &shdr );
    if( shdr.sh_type == SHT_DYNAMIC ) {
      dyns = (Elf64_Dyn*) malloc( shdr.sh_size );
      read_elf64_dynamic_section( fd, shdr.sh_offset, shdr.sh_size, dyns );
      n = m = shdr.sh_size / sizeof(Elf64_Dyn);
      for( j=0, k=0; j<n; j++, k++ ) {
	while( dyns[j].d_tag == DT_RPATH ) {
	  j ++;
	  m --;
	}
	if( j > k ) {
	  memcpy( &dyns[k], &dyns[j], sizeof(Elf64_Dyn) );
	}
      }
      for( ; k<n; k++ ) memset( &dyns[k], 0, sizeof(Elf64_Dyn) );
      if( m < n ) {
	write_elf64_dynamic_section( fd, shdr.sh_offset, shdr.sh_size, dyns );
	shdr.sh_size = m * sizeof(Elf64_Dyn);
	write_elf64_section_header( fd, i, &ehdr, &shdr );
      } else {
	fprintf( stderr, "No RPATH\n" );
      }
      free( dyns );
      (void) close( fd );
      return;
    }
  }
  (void) close( fd );
  fprintf( stderr, "Unable to find DYNAMIC section\n" );
  exit( 1 );
}

static void print_usage( char *prog ) {
  fprintf( stderr, "%s <bin>\n", prog );
  exit( 1 );
}

int main( int argc, char **argv ) {
  if( argc < 2 ) print_usage( argv[0] );
  rm_rpath( argv[1] );
  return 0;
}
