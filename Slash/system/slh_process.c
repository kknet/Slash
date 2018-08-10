//
//  slh_process.c
//  Slash
//
//  Created by Terminator on 2018/07/23.
//  Copyright © 2018年 digital-pers0n. All rights reserved.
//

#include "slh_process.h"
#include "slh_util.h"
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>
#include <spawn.h>
#include <stdbool.h>
#include <errno.h>
#include <signal.h>

extern char **environ;

static inline void prc_error(const char *str, const char *str2) {
    fprintf(stderr, "%s: %s failed with error %i %s\n", str, str2, errno, strerror(errno));
}

#pragma mark - Initialization

void prc_init(Process *p, char *const *args) {
    /* Copy args */
    p->args = malloc((args_len(args) + 1) * sizeof(char *));
    args_cpy(p->args, args);
    
    p->pid = -1;
    p->std_err = NULL;
    p->std_out = NULL;
    p->fa = NULL;
}

#pragma mark - Destruction

void prc_destroy(Process *p) {
    if (prc_pid(p) > 0) {
        prc_close(p);
    }
    args_free(p->args);
}

#pragma mark - Process launch

int prc_launch(Process *p) {
    
    if (p->pid > 0) { // kill previous process
        prc_kill(p);
    }
    
    int stdout_pipe[2];
    int stderr_pipe[2];
    posix_spawn_file_actions_t fa;
    
    /* create pipes */
    if (pipe(stdout_pipe) || pipe(stderr_pipe)) {
        prc_error(__func__, "pipe()");
        return -1;
    }
    
    /* init and configure file actions */
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_addclose(&fa, stdout_pipe[0]);
    posix_spawn_file_actions_addclose(&fa, stderr_pipe[0]);
    posix_spawn_file_actions_adddup2(&fa, stdout_pipe[1], 1);
    posix_spawn_file_actions_adddup2(&fa, stderr_pipe[1], 2);
    posix_spawn_file_actions_addclose(&fa, stdout_pipe[1]);
    posix_spawn_file_actions_addclose(&fa, stderr_pipe[1]);
    
    /* spawn a process */
    pid_t pid;
    if (posix_spawnp(&pid, p->args[0], &fa, NULL, p->args, environ) != 0) {
        prc_error(__func__, "posix_spawn()");
        posix_spawn_file_actions_destroy(&fa);
        return -1;
    }
    
    /* close child-side of pipes */
    close(stdout_pipe[1]);
    close(stderr_pipe[1]);
    
    /* associate streams with the file descriptors */
    if ((p->std_out = fdopen(stdout_pipe[0], "r")) == NULL ||
        (p->std_err = fdopen(stderr_pipe[0], "r")) == NULL) {
        prc_error(__func__, "fdopen()");
        posix_spawn_file_actions_destroy(&fa);
        return -1;
    }
    
    p->pid = pid;
    p->fa = fa;
    
    return 0;
}

#pragma mark - Process close

int prc_close(Process *p) {
    int exit_code;
    
    /* disassociate file streams */
    if (fclose(prc_stdout(p)) == EOF || fclose(prc_stderr(p)) == EOF) {
        prc_error(__func__, "fclose()");
    }
    
    waitpid(prc_pid(p), &exit_code, 0);
    
    if (posix_spawn_file_actions_destroy(&(p->fa)) != 0) {
        prc_error(__func__, "posix_spawn_file_actions_destroy()");
    }
    
    p->pid = -1;
    
    return exit_code;
}

#pragma mark - Process kill

int prc_kill(Process *p) {
    
    if (prc_pid(p) > 0) {
        
        /* TODO: use kill() function instead */
        char *pkill;
        asprintf(&pkill, "pkill -9 -P %i", prc_pid(p));
        system(pkill);
        free(pkill);
        
        
        /* disassociate file streams */
        if (fclose(prc_stdout(p)) == EOF || fclose(prc_stderr(p)) == EOF) {
            prc_error(__func__, "fclose()");
        }
        
        if (posix_spawn_file_actions_destroy(&(p->fa)) != 0) {
            prc_error(__func__, "posix_spawn_file_actions_destroy()");
        }
        p->pid = -1;
        
    } else {
        fprintf(stderr, "%s: invalid PID\n", __func__);
        return -1;
    }
    
    return 0;
}

#pragma mark - Process does exist

int prc_does_exist(Process *p) {
    if (prc_pid(p) < 0) {
        return -1;
    }
    return kill(prc_pid(p), 0);
}


