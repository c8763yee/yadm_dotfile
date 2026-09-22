#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef GRUB_CFG
#define GRUB_CFG "/boot/grub/grub.cfg"
#endif

typedef struct {
	char *title;
	char *target;
	size_t depth;
} Entry;

typedef struct {
	Entry *items;
	size_t count;
} EntryList;

static void *xrealloc(void *ptr, size_t size)
{
	void *p = realloc(ptr, size);

	if (!p) {
		perror("realloc");
		exit(EXIT_FAILURE);
	}
	return p;
}

static char *xstrdup(const char *s)
{
	char *p = strdup(s);

	if (!p) {
		perror("strdup");
		exit(EXIT_FAILURE);
	}
	return p;
}

static void entry_list_add(EntryList *list, const char *title,
			   const char *target, size_t depth)
{
	Entry *entry;

	list->items =
		xrealloc(list->items, (list->count + 1) * sizeof(*list->items));
	entry = &list->items[list->count++];
	entry->title = xstrdup(title);
	entry->target = xstrdup(target);
	entry->depth = depth;
}

static void entry_list_free(EntryList *list)
{
	for (size_t i = 0; i < list->count; i++) {
		free(list->items[i].title);
		free(list->items[i].target);
	}
	free(list->items);
}

static char *unquote(char *value)
{
	size_t length = strlen(value);

	if (length >= 2 && value[0] == '"' && value[length - 1] == '"') {
		value[length - 1] = '\0';
		return value + 1;
	}
	return value;
}

static int parse_grubby_output(EntryList *list)
{
	FILE *fp = popen("grubby --info=ALL", "r");
	char *line = NULL;
	size_t capacity = 0;
	char *title = NULL;
	int rc = -1;

	if (!fp) {
		perror("grubby");
		return -1;
	}
	while (getline(&line, &capacity, fp) != -1) {
		char *value = strchr(line, '=');

		if (!value)
			continue;
		*value++ = '\0';
		value[strcspn(value, "\n")] = '\0';
		value = unquote(value);
		if (strcmp(line, "index") == 0) {
			if (title)
				entry_list_add(list, title, title, 0);
			free(title);
			title = NULL;
		} else if (strcmp(line, "title") == 0) {
			free(title);
			title = xstrdup(value);
		}
	}
	if (title)
		entry_list_add(list, title, title, 0);
	if (pclose(fp) != 0) {
		fp = NULL;
		fprintf(stderr, "grubby failed\n");
		goto out;
	}
	fp = NULL;
	rc = 0;
out:
	free(line);
	free(title);
	if (fp)
		(void)pclose(fp);
	return rc;
}

static const char *ltrim(const char *s)
{
	while (*s && isspace((unsigned char)*s))
		s++;
	return s;
}

static int is_grub_command(const char *line, const char *command)
{
	size_t length = strlen(command);

	return strncmp(line, command, length) == 0 &&
	       (isspace((unsigned char)line[length]) || line[length] == '\'' ||
		line[length] == '\"');
}

static char *extract_title(const char *line)
{
	const char *start = strpbrk(line, "\"'");
	const char *end;
	char *title;
	size_t length;

	if (!start)
		return NULL;
	end = strchr(start + 1, *start);
	if (!end)
		return NULL;
	length = (size_t)(end - start - 1);
	title = xrealloc(NULL, length + 1);
	memcpy(title, start + 1, length);
	title[length] = '\0';
	return title;
}

static void count_braces(const char *line, int *opens, int *closes)
{
	*opens = 0;
	*closes = 0;
	for (; *line; line++) {
		if (*line == '{')
			(*opens)++;
		else if (*line == '}')
			(*closes)++;
	}
}

static char *build_target(char **parents, size_t depth, const char *title)
{
	size_t length = strlen(title) + 1;
	char *target;

	for (size_t i = 0; i < depth; i++)
		length += strlen(parents[i]) + 1;
	target = xrealloc(NULL, length);
	target[0] = '\0';
	for (size_t i = 0; i < depth; i++) {
		strcat(target, parents[i]);
		strcat(target, ">");
	}
	strcat(target, title);
	return target;
}

static int parse_grub_cfg_entries(EntryList *list, int windows_only)
{
	FILE *fp = fopen(GRUB_CFG, "r");
	char *line = NULL;
	char *parents[64] = { 0 };
	int submenu_brace_at[64] = { 0 };
	size_t capacity = 0;
	size_t depth = 0;
	int brace_level = 0;
	int rc = -1;

	if (!fp) {
		perror(GRUB_CFG);
		return -1;
	}
	while (getline(&line, &capacity, fp) != -1) {
		const char *trimmed = ltrim(line);
		int opens;
		int closes;

		count_braces(trimmed, &opens, &closes);
		if (is_grub_command(trimmed, "submenu") && depth < 64) {
			char *title = extract_title(trimmed);

			if (title) {
				parents[depth] = title;
				submenu_brace_at[depth++] = brace_level + opens;
			}
		} else if (is_grub_command(trimmed, "menuentry") &&
			   (!windows_only ||
			    strstr(trimmed, "--class windows") ||
			    strncasecmp(trimmed + 9, " 'Windows", 9) == 0 ||
			    strncasecmp(trimmed + 9, " \"Windows", 9) == 0)) {
			char *title = extract_title(trimmed);

			if (title) {
				char *target =
					build_target(parents, depth, title);

				entry_list_add(list, title, target, depth);
				free(target);
				free(title);
			}
		}
		brace_level += opens - closes;
		while (depth && brace_level < submenu_brace_at[depth - 1])
			free(parents[--depth]);
	}
	rc = 0;
	free(line);
	while (depth)
		free(parents[--depth]);
	fclose(fp);
	return rc;
}

static void json_string(const char *value)
{
	putchar('"');
	for (const unsigned char *p = (const unsigned char *)value; *p; p++) {
		switch (*p) {
		case '"':
			fputs("\\\"", stdout);
			break;
		case '\\':
			fputs("\\\\", stdout);
			break;
		case '\n':
			fputs("\\n", stdout);
			break;
		case '\r':
			fputs("\\r", stdout);
			break;
		case '\t':
			fputs("\\t", stdout);
			break;
		default:
			if (*p < 0x20)
				printf("\\u%04x", *p);
			else
				putchar(*p);
		}
	}
	putchar('"');
}

static void print_json(const EntryList *list)
{
	putchar('[');
	for (size_t i = 0; i < list->count; i++) {
		const Entry *entry = &list->items[i];

		if (i)
			putchar(',');
		printf("{\"index\":%zu,\"depth\":%zu,\"title\":", i,
		       entry->depth);
		json_string(entry->title);
		fputs(",\"target\":", stdout);
		json_string(entry->target);
		putchar('}');
	}
	puts("]");
}

static void print_menu(const EntryList *list)
{
	for (size_t i = 0; i < list->count; i++)
		printf("%zu: %*s%s\n", i, (int)(list->items[i].depth * 2), "",
		       list->items[i].title);
}

static int run_cmd(char *const argv[])
{
	pid_t pid = fork();
	int status;

	if (pid < 0) {
		perror("fork");
		return -1;
	}
	if (pid == 0) {
		execvp(argv[0], argv);
		perror(argv[0]);
		_exit(127);
	}
	if (waitpid(pid, &status, 0) < 0) {
		perror("waitpid");
		return -1;
	}
	return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

static int boot_entry(const Entry *entry)
{
	char *grub_reboot[] = { "grub2-reboot", entry->target, NULL };
	char *reboot[] = { "reboot", NULL };
	int rc;

	printf("Setting next boot entry to: %s\n", entry->target);
	rc = run_cmd(grub_reboot);
	if (rc != 0) {
		grub_reboot[0] = "grub-reboot";
		if ((rc = run_cmd(grub_reboot)) != 0) {
			fprintf(stderr, "grub-reboot failed (exit code %d)\n",
				rc);
			return rc ? rc : EXIT_FAILURE;
		}
	}
	fflush(stdout);
	rc = run_cmd(reboot);
	if (rc != 0)
		fprintf(stderr, "reboot failed (exit code %d)\n", rc);
	return rc ? rc : EXIT_SUCCESS;
}

static int parse_index(const char *value, size_t count, size_t *index)
{
	char *end;
	unsigned long parsed;

	errno = 0;
	parsed = strtoul(value, &end, 10);
	if (errno || end == value || *end || parsed >= count)
		return -1;
	*index = (size_t)parsed;
	return 0;
}

static int select_entry(const EntryList *list, size_t *index)
{
	char *line = NULL;
	size_t capacity = 0;
	int rc = -1;

	if (!list->count) {
		fprintf(stderr, "No boot entries found.\n");
		return -1;
	}
	print_menu(list);
	printf("Select next boot entry [0-%zu]: ", list->count - 1);
	fflush(stdout);
	if (getline(&line, &capacity, stdin) == -1)
		goto out;
	line[strcspn(line, "\n")] = '\0';
	if (parse_index(line, list->count, index) != 0)
		fprintf(stderr, "Invalid entry index: %s\n", line);
	else
		rc = 0;
out:
	free(line);
	return rc;
}

static int boot_index(const EntryList *list, size_t index)
{
	if (geteuid() != 0) {
		fprintf(stderr, "Boot selection requires root privileges.\n");
		return EXIT_FAILURE;
	}
	return boot_entry(&list->items[index]);
}

static void usage(const char *program)
{
	fprintf(stderr, "Usage: %s [--list | --boot INDEX]\n", program);
}

int main(int argc, char **argv)
{
	EntryList entries = { 0 };
	int rc = EXIT_SUCCESS;

	if (parse_grubby_output(&entries) == 0) {
		if (parse_grub_cfg_entries(&entries, 1) != 0) {
			rc = EXIT_FAILURE;
			goto out;
		}
	} else {
		entry_list_free(&entries);
		entries = (EntryList){ 0 };
		if (parse_grub_cfg_entries(&entries, 0) != 0) {
			rc = EXIT_FAILURE;
			goto out;
		}
	}
	if (argc == 1) {
		size_t index;

		if (select_entry(&entries, &index) != 0) {
			rc = EXIT_FAILURE;
			goto out;
		}
		rc = boot_index(&entries, index);
		goto out;
	}
	if (argc == 2 && strcmp(argv[1], "--list") == 0) {
		print_json(&entries);
		goto out;
	}
	if (argc == 3 && strcmp(argv[1], "--boot") == 0) {
		size_t index;

		if (parse_index(argv[2], entries.count, &index) != 0) {
			fprintf(stderr, "Invalid entry index: %s\n", argv[2]);
			rc = EXIT_FAILURE;
			goto out;
		}
		rc = boot_index(&entries, index);
		goto out;
	} else {
		usage(argv[0]);
		rc = EXIT_FAILURE;
	}
out:
	entry_list_free(&entries);
	return rc;
}
