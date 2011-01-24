/*****************************************************************************

Copyright (C) 2001-2008, Daniel Kroening, ETH Zurich,

All rights reserved. Redistribution and use in source and binary forms, with
or without modification, are permitted provided that the following
conditions are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

  3. All advertising materials mentioning features or use of this software
     must display the following acknowledgement:

     This product includes software developed by Daniel Kroening,
     ETH Zurich and Edmund Clarke, Computer Science Department,
     Carnegie Mellon University.

  4. Neither the name of the University nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.

  5. We must be notified by email at kroening@cs.cmu.edu after you install
     the program for any purpose.

   
THIS SOFTWARE IS PROVIDED BY THE UNIVERSITIES AND CONTRIBUTORS `AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
******************************************************************************/

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "ddverify.h"

#ifndef __linux__
#include <sys/types.h>

ssize_t
getline(char **lineptr, size_t *n, FILE *stream)
{
  char *ptr, *tmp;
  size_t l;
  
  if ((ptr=fgetln(stream, &l))==NULL)
    return -1;

  if (*lineptr==NULL || *n<(l+1)) 
  {
    if ((tmp=realloc(*lineptr, l+1))==NULL)
      return -1;
    *lineptr=tmp;
    *n=l+1;
  }
  memcpy(*lineptr, ptr, l);
  (*lineptr)[l] = '\0';
  return l;
}
#endif

void print_msg(char *msg)
{
    fprintf(stdout, "%s", msg);
    fflush(stdout);
}

void show_help()
{
    printf("\n");
    printf("********************************************************************\n");
    printf("*                                                                  *\n");
    printf("*                          DDVerify 0.1.c                          *\n");
    printf("*                                                                  *\n");
    printf("********************************************************************\n");
    printf("\n");
    printf("Usage:                              Purpose:\n\n");
    printf(" ddverify [-?] [-h] [--help]         show help\n");
    printf(" -D macro                            define preprocessor macro\n");
    printf(" --16, --32, --64                    set width of machine word\n");
    printf(" --modelchecker #                    set the modelchecker to be used\n");
    printf(" --iterations #                      set maximum number of refinement iterations\n");
    printf(" --unwind #                          set maximum depth of unwinding\n");
    printf(" --unwindset #:#                     set maximum depth of unwinding for a loop\n");
    printf(" --ddv-path                          set ddverify path\n");
    printf(" --module-init                       set module initalization function\n");
    printf(" --module-exit                       set module cleanup function\n");
    printf(" --driver-type #                     set driver type (char, block or net)\n");
    printf(" --model #                           set the verification model (seq or con)\n");
    printf(" --prepare-only                      stop after preparation\n");
    printf(" --check-bounds                      array bounds check\n");
    printf(" --check-pointer                     pointer check\n");
    printf(" --check-spinlock                    spinlock check\n");
    printf(" --check-semaphore                   semaphore check\n");
    printf(" --check-mutex                       mutex check\n");
    printf(" --check-io                          I/O communication check\n");
    printf(" --check-wait-queue                  wait queue check\n");
    printf(" --check-tasklet                     tasklet check\n");
    printf(" --check-work-queue                  work queue check\n");
    printf(" --check-timer                       timer check\n");
    printf(" --check-context                     context check\n");
    printf(" --no-slicing                        turn slicing off for CBMC\n");
    printf(" --cbmc                              use CBMC as verification tool\n");
    printf(" --satabs                            use SATABS as verification tool (default)\n");
    printf("\n");
    
    exit(0);
}


void set_number_iterations(char *number)
{
  strcpy(number_iterations, number);
}

// extends the unwindset string
void set_unwindset(char *set)
{
  if (unwindset==NULL)
  {
    unwindset=malloc(unwindset_str_size);
    if (unwindset==NULL)
      exit(-1);
    unwindset[0]='\0';
  }
  if (strlen(unwindset)+strlen(set)+strlen(UNWINDSET_PARAM)+1>unwindset_str_size)
  {
    unwindset_str_size+=strlen(set)+strlen(UNWINDSET_PARAM)+STR_LENGTH;
    unwindset=realloc(unwindset, unwindset_str_size);
    if (unwindset==NULL)
      exit(-1);
  }
  strcat(unwindset, UNWINDSET_PARAM);
  strcat(unwindset, set);
}

void set_unwind(char *set)
{
  if(unwind!=NULL) 
    free(unwind); // somebody decided to provide two --unwind params
  unwind=malloc(strlen(set)+1);
  if(unwind==NULL)
    exit(-1);
  strcpy(unwind, set);
}

void set_ddv_path(char *path)
{
    int i;

    strcpy(ddv_path, path);
    i = strlen(ddv_path) - 1;
    
    if (ddv_path[i] != '/') {
	strcat(ddv_path, "/");
    }
}

void set_driver_type(char *type)
{
    if (strcmp(type, "char") == 0) {
	driver_type = DRIVER_TYPE_CHAR;
	return;
    }

    if (strcmp(type, "block") == 0) {
	driver_type = DRIVER_TYPE_BLOCK;
	return;
    }

    if (strcmp(type, "net") == 0) {
	driver_type = DRIVER_TYPE_NET;
	
	fprintf(stderr, "Error: Network driver are not supported!\n");
	exit(-1);
    }

    fprintf(stderr, "Error: Driver type not recognized. Use \"char\", \"block\" or \"net\".\n");
    exit(-1);
}

void set_model_type(char *type)
{
    if (strcmp(type, "seq1") == 0) {
	model_type = MODEL_TYPE_SEQUENTIAL1;
	strcpy(include_path,"models/seq1/include");
	strcpy(src_path,"models/seq1/src/");
	return;
    }

    if (strcmp(type, "con1") == 0) {
	model_type = MODEL_TYPE_CONCURRENT1;
	strcpy(include_path,"models/con1/include");
	strcpy(src_path,"models/con1/src/");
	return;
    }

   if (strcmp(type, "con2") == 0) {
	model_type = MODEL_TYPE_CONCURRENT2;
	strcpy(include_path,"models/con2/include");
	strcpy(src_path,"models/con2/src/");
	return;
    }

    fprintf(stderr, "Error: Model type not recognized. Use either \"seq1\", \"con1\", or \"con2\".\n");
    exit(-1);
}

void write_cc_file()
{
    FILE *fp;
    char content[5000];
    int fh;

    strcpy(content, "#include <ddverify/ddverify.h>\n");
    
    strcat(content, "#include \"");
    strcat(content, file[0]);
    strcat(content, "\"\n\n");
    
    strcat(content, "int main()\n");
    strcat(content, "{\n");
    
    if (strcmp(module_init, "") != 0) {
	strcat(content, "   _ddv_module_init = ");
	strcat(content, module_init);
	strcat(content, ";\n");
    }

    if (strcmp(module_exit, "") != 0) {
	strcat(content, "   _ddv_module_exit = ");
	strcat(content, module_exit);
	strcat(content, ";\n");
    }

    strcat(content, "   call_ddv();\n\n");
    strcat(content, "   return 0;\n");
    strcat(content, "}\n");
    
    if ((fh = open(output_cc_file, O_CREAT | O_TRUNC | O_RDWR, S_IRUSR | S_IWUSR )) != -1) {
	close(fh);
	
	fp = fopen(output_cc_file, "a");
	fprintf(fp, "%s", content);
	fclose(fp);
    } else {
	fprintf(stderr, "Error: Could not create c file!\n");
	exit(-1);
    }
}

void get_preprocessor_string(char *str)
{
    int i;

    strcpy(str, " -D __KERNEL__ -D MODULE ");

    if (driver_type == DRIVER_TYPE_CHAR) {
	strcat(str, " -D DRIVER_TYPE_CHAR ");
    } else if (driver_type == DRIVER_TYPE_BLOCK) {
	strcat(str, " -D DRIVER_TYPE_BLOCK ");
    }

    if (driver_type_pci) {
        strcat(str, " -D DRIVER_TYPE_PCI ");
    }

    if (model_type == MODEL_TYPE_SEQUENTIAL1) {
	strcat(str, " -D MODEL_TYPE_SEQUENTIAL1 ");
    } else if (model_type == MODEL_TYPE_CONCURRENT1) {
	strcat(str, " -D MODEL_TYPE_CONCURRENT1 ");
    }

    if (check_spinlock) {
	strcat(str, " -D DDV_ASSERT_SPINLOCK ");
    }
    if (check_semaphore) {
	strcat(str, " -D DDV_ASSERT_SEMAPHORE ");
    }
    if (check_mutex) {
	strcat(str, " -D DDV_ASSERT_MUTEX ");
    }
    if (check_io) {
	strcat(str, " -D DDV_ASSERT_IO ");
    }
    if (check_wait_queue) {
	strcat(str, " -D DDV_ASSERT_WAIT_QUEUE ");
    }
    if (check_tasklet) {
	strcat(str, " -D DDV_ASSERT_TASKLET ");
    }
    if (check_work_queue) {
	strcat(str, " -D DDV_ASSERT_WORK_QUEUE ");
    }
    if (check_timer) {
	strcat(str, " -D DDV_ASSERT_TIMER ");
    }
    if (check_context) {
	strcat(str, " -D DDV_ASSERT_CONTEXT ");
    }
    
    for (i = 0; i < nr_macro_registered; i++) {
	strcat(str, " -D ");
	strcat(str, macro[i]);
    }    
}

void write_compile_script()
{
    FILE *fp;
    char script[10000];
    string tmp;
    int i, fh;
    
    strcpy(script, "#!/bin/bash\n");
    
    strcat(script, "gcc -c -I ");
    strcat(script, ddv_path);
    strcat(script, include_path);
    
    get_preprocessor_string(tmp);
    strcat(script, tmp);
    strcat(script, " \\\n");
    
    strcat(script, output_cc_file);
    strcat(script, " \\\n");
    
    for (i = 1; i < nr_file_registered; i++) {
	strcat(script, file[i]);
	strcat(script, " \\\n");
    }
    
    for (i = 0; i < nr_ddv_files; i++) {
	strcat(script, ddv_path);
	strcat(script, src_path);
	strcat(script, ddv_files[i]);
	strcat(script, " \\\n");
    }
    
    
    if ((fh = open(output_compile_file, O_CREAT | O_TRUNC | O_RDWR, S_IRWXU)) != -1) {
	close(fh);
	
	fp = fopen(output_compile_file, "a");
	fprintf(fp, "%s", script);
	fclose(fp);
    } else {
	fprintf(stderr, "Error: Could not create compile script!\n");
	exit(-1);
    }
}


void write_tool_script()
{
    FILE *fp;
    char script[10000];
    string tmp;
    int i, fh;
    
    strcpy(script, "#!/bin/bash\n");
    
    strcat(script, (tool==SATABS)?"satabs":"cbmc");
    strcat(script, " $* ");
    
    if (check_bounds) {
	strcat(script, " --bounds-check ");
    }
    if (check_pointer) {
	strcat(script, " --pointer-check ");
    }
    if (check_div_by_zero) {
	strcat(script, " --div-by-zero-check ");       
    }
    
    switch (word_width) {
	case 16:
	    strcat(script, " --16 ");
	    break;
	case 32:
	    strcat(script, " --32 ");
	    break;
	case 64:
	    strcat(script, " --64 ");
	    break;
	default:
	    fprintf(stderr, "Error: Wrong word width!\n");
	    break;
    }

    if (tool==SATABS && strcmp(modelchecker, "") != 0) {
      strcat(script, " --modelchecker ");
      strcat(script, modelchecker);
      strcat(script, " ");
    }

    if (tool==SATABS) {
      strcat(script, " --iterations ");
      strcat(script, number_iterations);
      strcat(script, " ");
    }

    if (tool==CBMC && unwindset!=NULL) {
      strcat(script, unwindset);
      strcat(script, " ");
    }

    if (tool==CBMC && unwind!=NULL) {
      strcat(script, " --unwind ");
      strcat(script, unwind);
      strcat(script, " ");
    }

    if (tool==CBMC && cbmc_slicing)
      strcat(script, " --slice ");
    
    strcat(script, " -I ");
    strcat(script, ddv_path);
    strcat(script, include_path);
    
    get_preprocessor_string(tmp);
    strcat(script, tmp);   
    strcat(script, " \\\n");
    
    strcat(script, output_cc_file);
    strcat(script, " \\\n");
    
    for (i = 1; i < nr_file_registered; i++) {
	strcat(script, file[i]);
	strcat(script, " \\\n");
    }
    
    for (i = 0; i < nr_ddv_files; i++) {
	strcat(script, ddv_path);
	strcat(script, src_path);
	strcat(script, ddv_files[i]);
	strcat(script, " \\\n");
    }
    
    
    if ((fh = open(output_tool_file, O_CREAT | O_TRUNC | O_RDWR, S_IRWXU)) != -1) {
	close(fh);
	
	fp = fopen(output_tool_file, "a");
	fprintf(fp, "%s", script);
	fclose(fp);
    } else {
	fprintf(stderr, "Error: Could not create Satabs script!\n");
	exit(-1);
    }
}

void read_output_file()
{
    int ret, line_nr;
    size_t t = 0;
    char *buffer = NULL, *ptr;
    char **lineptr = &buffer;

    FILE *fp = fopen(".ddv_output_2", "r");

    if (!fp) {
	fprintf(stderr, "\nError: Could not open output file!\n");
	exit(-1);
    }

    number_claims = 0;
    line_nr = 0;
    while((ret = getline(lineptr, &t, fp)) > 0) {	
	switch (line_nr % 6) {
	    case 0:
		claim[number_claims].claim_id = buffer;
                ptr=strchr(buffer, '\n'); if(ptr!=NULL) *ptr=0;
                ptr=strchr(buffer, '\r'); if(ptr!=NULL) *ptr=0;
		break;
	    case 1:
		claim[number_claims].file = buffer;

		break;
	    case 2:
		claim[number_claims].line = atoi(buffer);

		break;
	    case 3:
		claim[number_claims].text = buffer;

		break;
	    case 4:
		claim[number_claims].claim = buffer;

		break;
	    case 5:
		// empty line
		number_claims++;

		break;
	    default:
		break;
	}
	line_nr++;
	buffer = NULL;
    }
    fclose(fp);
}

void prove_claims_satabs()
{
    int i, ret;
    char tmp[1000];
    char cmd[1000];
    FILE *fp;
    size_t t = 1000;
    char* buffer = (char*) malloc(sizeof(char)*t);
    char **lineptr = &buffer;

    for (i = 0; i < number_claims; i++) {
	sprintf(tmp, "claim %d of %d ", (i + 1), number_claims);
	print_msg(tmp);

	if (strcmp(claim[i].claim, "TRUE") == 0) {
	    printf("SUCCESSFULL 0 \n");
	} else {
	    sprintf(cmd, "./ddv_satabs --claim %s > .claim_out_%s 2>&1", 
		    claim[i].claim_id, claim[i].claim_id);
	    ret = system(cmd);
	    ret = WEXITSTATUS(ret);
	    if(ret==0 || ret==10) {
		sprintf(cmd, "awk -f %sawk/get_verification_result .claim_out_%s", 
			ddv_path, claim[i].claim_id);
		system(cmd);
	    }
	    else if(ret==11)
	    {
	        print_msg("TOO_MANY_ITERATIONS\t");
	    	sprintf(cmd, "awk -f %sawk/get_too_many_iterations_result .claim_out_%s", 
			ddv_path, claim[i].claim_id);
		system(cmd);
	     } else {
		print_msg("ERROR\n");
	    }
	}

    }
    free(buffer);
}

void prove_claims_cbmc()
{
    int i, ret;
    char tmp[1000];
    char cmd[1000];
    FILE *fp;
    size_t t = 1000;
    char* buffer = (char*) malloc(sizeof(char)*t);
    char **lineptr = &buffer;

    for (i = 0; i < number_claims; i++) {
	sprintf(tmp, "claim %d ", (i + 1));
	print_msg(tmp);

	if (strcmp(claim[i].claim, "TRUE") == 0) {
	    printf("SUCCESSFULL 0 \n");
	} else {
	    sprintf(cmd, "./ddv_cbmc --claim %s > .claim_out_%s 2>&1", 
		    claim[i].claim_id, claim[i].claim_id);
	    ret = system(cmd);
	    ret = WEXITSTATUS(ret);
	    if(ret==0 || ret==10) {
		sprintf(cmd, "awk -f %sawk/get_verification_result .claim_out_%s", 
			ddv_path, claim[i].claim_id);
		system(cmd);
	    }
	    else {
		print_msg("ERROR\n");
	    }
	}

    }
    free(buffer);
}

void run_satabs()
{
    char cmd[1000];

    print_msg("Running satabs ..");
    if (system("./ddv_satabs --show-claims > .ddv_output_1") == 0) {
	fprintf(stderr, "\nError: Could not start Satabs!\n");
	exit(-1);
    }
    print_msg(".\n");   

    print_msg("Parsing satabs output ..");
    sprintf(cmd, "awk -f %sawk/convert_satabs_output .ddv_output_1 > .ddv_output_2", ddv_path);
    system(cmd);
    print_msg(".\n");

    read_output_file();

    printf("%d Claims\n", number_claims);

    prove_claims_satabs();
}

void run_cbmc()
{
    char cmd[1000];

    print_msg("Running CBMC ..");
    if (system("./ddv_cbmc --show-claims > .ddv_output_1") != 0) {
	fprintf(stderr, "\nError: Could not start CBMC!\n");
	exit(-1);
    }
    print_msg(".\n");   

    print_msg("Parsing CBMC output ..");
    sprintf(cmd, "awk -f %sawk/convert_satabs_output .ddv_output_1 > .ddv_output_2", ddv_path);
    system(cmd);
    print_msg(".\n");

    read_output_file();

    printf("%d Claims\n", number_claims);

    prove_claims_cbmc();
}

void parse_args(int argc, char **argv)
{
    int cmd;

    while (1) {
	int option_index = 0;
	static struct option long_options[] = {
	    {"help", 0, 0, 0},
	    {"16", 0, 0, 0},
	    {"32", 0, 0, 0},
            {"64", 0, 0, 0},
	    {"modelchecker", 1, 0, 0},
	    {"iterations", 1, 0, 0},
	    {"ddv-path", 1, 0, 0},
	    {"module-init", 1, 0, 0},
	    {"module-exit", 1, 0, 0},
	    {"driver-type", 1, 0, 0},
            {"model", 1, 0, 0},
	    {"prepare-only", 0, 0, 0},
	    {"check-bounds", 0, 0, 0},
	    {"check-pointer", 0, 0, 0},
	    {"check-spinlock", 0, 0, 0},
	    {"check-semaphore", 0, 0, 0},
	    {"check-mutex", 0, 0, 0},
            {"check-io", 0, 0, 0},
	    {"check-wait-queue", 0, 0, 0},
	    {"check-tasklet", 0, 0, 0},
	    {"check-work-queue", 0, 0, 0},
	    {"check-timer", 0, 0, 0},
	    {"check-context", 0, 0, 0},
	    {"cbmc", 0, 0, 0},
	    {"satabs", 0, 0, 0},
	    {"unwindset", 1, 0, 0},
	    {"unwind", 1, 0, 0},
	    {"no-slicing", 0, 0, 0},
	    {0, 0, 0, 0}
	};

	cmd = getopt_long(argc, argv, "?hD:1", long_options, &option_index);
	if (cmd == -1) {
	    break;
	}

	switch (cmd) {
	    case 0:
		switch (option_index) {
		    case 0:
			show_help();
			break;
		    case 1:
			word_width = 16;
			break;
		    case 2:
			word_width = 32;
			break;
		    case 3:
			word_width = 64;
			break;
   		    case 4:
		        strcpy(modelchecker, optarg);
		        break;
		    case 5:
		        set_number_iterations(optarg);
		        break;
		    case 6:
		        set_ddv_path(optarg);
			break;
		    case 7:
		        strcpy(module_init, optarg);
			break;
		    case 8:
		        strcpy(module_exit, optarg);
			break;
		    case 9:
			set_driver_type(optarg);
			break;
		    case 10:
			set_model_type(optarg);
			break;
		    case 11:
			prepare_only = 1;
			break;
		    case 12:
			check_bounds = 1;
			break;
		    case 13:
			check_pointer = 1;
			break;
		    case 14:
			check_spinlock = 1;
			break;
		    case 15:
			check_semaphore = 1;
			break;
		    case 16:
			check_mutex = 1;
			break;
		    case 17:
			check_io = 1;
			break;
		    case 18:
			check_wait_queue = 1;
			break;
		    case 19:
			check_tasklet = 1;
			break;
		    case 20:
			check_work_queue = 1;
			break;
		    case 21:
			check_timer = 1;
			break;
		    case 22:
			check_context = 1;
			break;
		    case 23:
			tool = CBMC;
			break;
		    case 24:
			tool = SATABS;
			break;
		    case 25:
			set_unwindset(optarg);
			break;
		    case 26:
			set_unwind(optarg);
			break;
		    case 27:
			cbmc_slicing = 0;
			break;
		    default:
			printf("?? ??\n");
			break;
		}

		break;
	    case 'h':
		show_help();
		break;
	    case '?':
		show_help();
		break;
	    case 'D':
	        if (nr_macro_registered < NR_MACRO_SUPPORT) {
		   strcpy(macro[nr_macro_registered], optarg);
		   nr_macro_registered++;
	        } else {
		   fprintf(stderr, "Error: Too many macros in project file!\n");
		   exit(-1);
	        }	        
	        break;
	    default:
		printf("?? getopt returned character code 0%o ??\n", cmd);
	}
    }

    if (optind < argc) {
      while (optind < argc) {
	if (nr_file_registered < NR_FILE_SUPPORT) {
	  strcpy(file[nr_file_registered], argv[optind++]);
	  nr_file_registered++;
	} else {
	  fprintf(stderr, "Error: Too many files in project file!\n");
	  exit(-1);
	}
      }
    }    	
}

void parse_file()
{
    int ret;
    char cmd[1000];
    char tmp[1000];
    FILE *fp;
    size_t t = 1000;
    char* buffer = (char*)malloc(sizeof(char)*1000);
    char **lineptr = &buffer;

    sprintf(cmd, "awk -f %sawk/parse_dd_file %s > .ddv_output_3", ddv_path, file[0]);
    system(cmd);

    fp = fopen(".ddv_output_3", "r");
    if (!fp) {
	fprintf(stderr, "Error: Could not parse main driver file!\n");
	exit(-1);
    }

    while((ret = getline(lineptr, &t, fp)) > 0) {
	if (strcmp(*lineptr, "MODULE_INIT\n") == 0) {
	    getline(lineptr, &t, fp);

	    if (strcmp(module_init, "") == 0) {
		strcpy(tmp, *lineptr);
		strncpy(module_init, &tmp[12], 
			strlen(tmp) - 12 - (strlen(tmp) - (strchr(tmp, ')') - tmp)));
	    }
			
	    continue;
	}

	if (strcmp(*lineptr, "MODULE_EXIT\n") == 0) {
	    getline(lineptr, &t, fp);

	    if (strcmp(module_exit, "") == 0) {
		strcpy(tmp, *lineptr);
		strncpy(module_exit, &tmp[12], 
			strlen(tmp) - 12 - (strlen(tmp) - (strchr(tmp, ')') - tmp)));
	    }

	    continue;
	}

	if (strcmp(*lineptr, "INCLUDE\n") == 0) {
	    getline(lineptr, &t, fp);

	    if (driver_type == 0) {
		if (strcmp(*lineptr, "<linux/miscdevice.h>\n") == 0) {
		    driver_type = DRIVER_TYPE_CHAR;
		}

		if (strcmp(*lineptr, "<linux/cdev.h>\n") == 0) {
		    driver_type = DRIVER_TYPE_CHAR;
		}

		if (strcmp(*lineptr, "<linux/blkdev.h>\n") == 0) {
		    driver_type = DRIVER_TYPE_BLOCK;
		}
	    }

	    if (strcmp(*lineptr, "<linux/pci.h>\n") == 0) {
	      driver_type_pci = 1;
	    }

	    continue;
	}


	fclose(fp);
	fprintf(stderr, "Error while parsing main driver file!\n");
	exit(-1);
    }
    free(buffer);

    fclose(fp);
}

void print_driver_information()
{
    printf("Module initalization function: %s\n", module_init);
    printf("Module cleanup function: %s\n", module_exit);
    
    switch (driver_type) {
	case DRIVER_TYPE_CHAR:
	    printf("Device driver type: char\n");
	    break;
	    
	case DRIVER_TYPE_BLOCK:
	    printf("Device driver type: block\n");
	    break;

	case DRIVER_TYPE_NET:
	    printf("Device driver type: net\n");
	    break;

	default:
	    break;
    }

    if (driver_type_pci) {
        printf("PCI interface: yes\n");
    } else {
        printf("PCI interface: no\n");
    }
}

int main(int argc, char **argv)
{
    char *tmp;

    tmp = getenv("DDV_PATH");
    if (tmp) {
	set_ddv_path(tmp);
    }

    parse_args(argc, argv);

    strcpy(output_cc_file, DEFAULT_CC_FILE);
    strcpy(output_compile_file, DEFAULT_COMPILE_SCRIPT);
    strcpy(output_tool_file, tool==SATABS?DEFAULT_SATABS_SCRIPT:DEFAULT_CBMC_SCRIPT);
  
    if (strcmp(ddv_path, "") == 0) {
	fprintf(stderr, "Error: could not find ddverify path!\n");
	exit(-1);
    }

    if (nr_file_registered == 0) {
	fprintf(stderr, "Error: no source file given!\n");
	exit(-1);
    }

    parse_file();

    if (driver_type == 0) {
	fprintf(stderr, "Error: no driver type set!\n");
	exit(-1);
    }

    print_driver_information();

    write_cc_file();
    write_compile_script();
    write_tool_script();

    if (!prepare_only) {
        tool==SATABS?run_satabs():run_cbmc();
    }

    exit(0);
}
