// SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
#include <signal.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
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
	if (argc < 4) {
		fprintf(stderr, "Usage: %s <ifindex> <clat addr> <plat addr>\n", argv[0]);
		return -1;
	}

	const int iface = atoi(argv[1]);
	const char *debug_path = NULL;
	if (argc >= 5) {
		debug_path = argv[argc - 1];
	}


	struct clat_bpf *skel;
	int err;
	bool ingress_hooked = false, egress_hooked = false;

	libbpf_set_print(libbpf_print_fn);

	if (debug_path) {
		FILE *f = fopen(debug_path, "rb");
		if (!f) {
			fprintf(stderr, "Failed to open debug BPF object '%s': %s\n", debug_path, strerror(errno));
			return -2;
		}
		if (fseek(f, 0, SEEK_END) != 0) {
			fclose(f);
			fprintf(stderr, "Failed to stat debug BPF object '%s'\n", debug_path);
			return -2;
		}
		long sz = ftell(f);
		if (sz <= 0) {
			fclose(f);
			fprintf(stderr, "Debug BPF object '%s' seems empty\n", debug_path);
			return -2;
		}
		rewind(f);
		void *buf = malloc(sz);
		if (!buf) {
			fclose(f);
			fprintf(stderr, "Out of memory\n");
			return -2;
		}
		if (fread(buf, 1, sz, f) != (size_t)sz) {
			free(buf);
			fclose(f);
			fprintf(stderr, "Failed to read debug BPF object '%s'\n", debug_path);
			return -2;
		}
		fclose(f);

		skel = calloc(1, sizeof(*skel));
		if (!skel) {
			free(buf);
			fprintf(stderr, "Out of memory\n");
			return -2;
		}
		err = clat_bpf__create_skeleton(skel);
		if (err) {
			free(buf);
			clat_bpf__destroy(skel);
			fprintf(stderr, "Failed to create skeleton: %d\n", err);
			return -2;
		}

		/* Replace embedded ELF data with the external buffer */
		skel->skeleton->data = buf;
		skel->skeleton->data_sz = sz;

		err = bpf_object__open_skeleton(skel->skeleton, NULL);
		free(buf);
		if (err) {
			clat_bpf__destroy(skel);
			fprintf(stderr, "Failed to open BPF object from '%s': %d\n", debug_path, err);
			return -2;
		}
		err = clat_bpf__load(skel);
		if (err) {
			fprintf(stderr, "Failed to load BPF object from '%s': %d\n", debug_path, err);
			clat_bpf__destroy(skel);
			return -2;
		}
		printf("Loaded BPF object from '%s'\n", debug_path);
	} else {
		skel = clat_bpf__open_and_load();
		if (!skel) {
			fprintf(stderr, "Failed to open BPF skeleton\n");
			return -2;
		}
	}

	// TODO: Handle size suffix correctly
	inet_pton(AF_INET6, argv[2], &skel->bss->CLAT_PREFIX);
	inet_pton(AF_INET6, argv[3], &skel->bss->PLAT_PREFIX);

	LIBBPF_OPTS(bpf_tc_hook, ingress_hook, .ifindex = iface, .attach_point = BPF_TC_INGRESS);
	err = bpf_tc_hook_create(&ingress_hook);
	if (err && err != -EEXIST) {
		fprintf(stderr, "Failed to create ingress hook: %d\n", err);
		goto cleanup;
	}
	ingress_hooked = true;

	LIBBPF_OPTS(bpf_tc_opts, ingress_tc_opts, .handle = 1, .priority = 1);
	ingress_tc_opts.prog_fd = bpf_program__fd(skel->progs.clat_ingress_6to4);
	err = bpf_tc_attach(&ingress_hook, &ingress_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to attach ingress hook: %d\n", err);
		goto cleanup;
	}

	LIBBPF_OPTS(bpf_tc_hook, egress_hook, .ifindex = iface, .attach_point = BPF_TC_EGRESS);
	err = bpf_tc_hook_create(&egress_hook);
	if (err && err != -EEXIST) {
		fprintf(stderr, "Failed to create egress hook: %d\n", err);
		goto cleanup;
	}
	egress_hooked = true;

	LIBBPF_OPTS(bpf_tc_opts, egress_tc_opts, .handle = 1, .priority = 1);
	egress_tc_opts.prog_fd = bpf_program__fd(skel->progs.clat_egress_4to6);
	err = bpf_tc_attach(&egress_hook, &egress_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to attach egress hook: %d\n", err);
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

	ingress_tc_opts.flags = ingress_tc_opts.prog_fd = ingress_tc_opts.prog_id = 0;
	err = bpf_tc_detach(&ingress_hook, &ingress_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to detach TC: %d\n", err);
		goto cleanup;
	}

	egress_tc_opts.flags = egress_tc_opts.prog_fd = egress_tc_opts.prog_id = 0;
	err = bpf_tc_detach(&egress_hook, &egress_tc_opts);
	if (err) {
		fprintf(stderr, "Failed to detach TC: %d\n", err);
		goto cleanup;
	}

cleanup:
	if (ingress_hooked)
		bpf_tc_hook_destroy(&ingress_hook);
	if (egress_hooked)
		bpf_tc_hook_destroy(&egress_hook);
	clat_bpf__destroy(skel);
	return -err;
}
