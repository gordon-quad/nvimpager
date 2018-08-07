#!/bin/sh

printf 1:
ps -o pid=,comm=,args= $$
printf 2:
ps -o pid=,comm=,args= $(ps -o ppid= $$)
printf 2:
ps -o pid=,comm=,args= $(ps -o ppid= $(ps -o ppid= $$))

ps -o pid,ppid,comm,cmd

nvim --cmd "echo nvim_get_proc($$)" --cmd q
