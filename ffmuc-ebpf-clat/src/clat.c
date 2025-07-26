// SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
#include <signal.h>
#include <unistd.h>
#include <arpa/inet.h>
#include "clat.skel.h"

static volatile sig_atomic_t exiting = 0;

static void sig_int(int signo)
{
	exiting = 1;
}

static int libbpf_print_fn(enum libbpf_print_level level, const char *format, va_list args) {
	return vfprintf(stderr, format, args);
}

int main(int argc, char **argv) {
	if (argc < 5) {
		fprintf(stderr, "Usage: %s <downstream ifindex> <upstream ifindex> <clat addr> <plat addr>\n", argv[0]);
		return -1;
	}

	const int downstream_iface = atoi(argv[1]), upstream_iface = atoi(argv[2]);
	struct clat_bpf *skel;
	int err;
	bool downstream_hooked = false, upstream_hooked = false;

	libbpf_set_print(libbpf_print_fn);

	skel = clat_bpf__open_and_load();
	if (!skel) {
		fprintf(stderr, "Failed to open BPF skeleton\n");
		return -2;
	}

	inet_pton(AF_INET6, argv[3], &skel->bss->CLAT_PREFIX);
	inet_pton(AF_INET6, argv[4], &skel->bss->PLAT_PREFIX);

	LIBBPF_OPTS(bpf_tc_hook, downstream_hook, .ifindex = downstream_iface, .attach_point = BPF_TC_INGRESS);
	err = bpf_tc_hook_create(&downstream_hook);
	if (err && err != -EEXIST) {
		fprintf(stderr, "Failed to create TC hook: %d\n", err);
		goto cleanup;
	}
	downstream_hooked = true;

	LIBBPF_OPTS(bpf_tc_opts, downstream_tc_opts, .handle = 1, .priority = 1);
	downstream_tc_opts.prog_fd = bpf_program__fd(skel->progs.clat_downstream);
	err = bpf_tc_attach(&downstream_hook, &downstream_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to attach TC: %d\n", err);
		goto cleanup;
	}

	LIBBPF_OPTS(bpf_tc_hook, upstream_hook, .ifindex = upstream_iface, .attach_point = BPF_TC_INGRESS);
	err = bpf_tc_hook_create(&upstream_hook);
	if (err && err != -EEXIST) {
		fprintf(stderr, "Failed to create TC hook: %d\n", err);
		goto cleanup;
	}
	upstream_hooked = true;

	LIBBPF_OPTS(bpf_tc_opts, upstream_tc_opts, .handle = 1, .priority = 1);
	upstream_tc_opts.prog_fd = bpf_program__fd(skel->progs.clat_upstream);
	err = bpf_tc_attach(&upstream_hook, &upstream_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to attach TC: %d\n", err);
		goto cleanup;
	}

	if (signal(SIGINT, sig_int) == SIG_ERR) {
		err = errno;
		fprintf(stderr, "Can't set signal handler: %s\n", strerror(errno));
		goto cleanup;
	}

	printf("Successfully started! Please run `sudo cat /sys/kernel/debug/tracing/trace_pipe` "
				 "to see output of the BPF program.\n");

	while (!exiting) {
		fprintf(stderr, ".");
		sleep(1);
	}

	downstream_tc_opts.flags = downstream_tc_opts.prog_fd = downstream_tc_opts.prog_id = 0;
	err = bpf_tc_detach(&downstream_hook, &downstream_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to detach TC: %d\n", err);
		goto cleanup;
	}

	upstream_tc_opts.flags = upstream_tc_opts.prog_fd = upstream_tc_opts.prog_id = 0;
	err = bpf_tc_detach(&upstream_hook, &upstream_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to detach TC: %d\n", err);
		goto cleanup;
	}

cleanup:
	if (downstream_hooked)
		bpf_tc_hook_destroy(&downstream_hook);
	if (upstream_hooked)
		bpf_tc_hook_destroy(&upstream_hook);
	clat_bpf__destroy(skel);
	return -err;
}
