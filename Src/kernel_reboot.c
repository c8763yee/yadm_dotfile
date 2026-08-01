#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct Menu {
	char *title;
	int is_submenu;
	struct Menu **children;
	size_t child_count;
} Menu;

typedef struct {
	char *title;
	char *target;
	size_t depth;
} Entry;

typedef struct {
	Entry *items;
	size_t count;
} EntryList;

static void *xmalloc(size_t size)
{
	void *p = malloc(size);

	if (!p) {
		perror("malloc");
		exit(EXIT_FAILURE);
	}
	return p;
}

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

static Menu *menu_new(const char *title, int is_submenu)
{
	Menu *menu = xmalloc(sizeof(*menu));

	menu->title = xstrdup(title);
	menu->is_submenu = is_submenu;
	menu->children = NULL;
	menu->child_count = 0;
	return menu;
}

static void menu_add_child(Menu *parent, Menu *child)
{
	parent->children =
		xrealloc(parent->children,
			 (parent->child_count + 1) * sizeof(*parent->children));
	parent->children[parent->child_count++] = child;
}

static void menu_free(Menu *menu)
{
	if (!menu)
		return;
	for (size_t i = 0; i < menu->child_count; i++)
		menu_free(menu->children[i]);
	free(menu->children);
	free(menu->title);
	free(menu);
}

static const char *ltrim(const char *s)
{
	while (*s && isspace((unsigned char)*s))
		s++;
	return s;
}

static char *extract_quoted_title(const char *line)
{
	const char *start = strchr(line, '\'');
	const char *end;
	char *title;
	size_t length;

	if (!start)
		return NULL;
	end = strchr(start + 1, '\'');
	if (!end)
		return NULL;

	length = (size_t)(end - start - 1);
	title = xmalloc(length + 1);
	memcpy(title, start + 1, length);
	title[length] = '\0';
	return title;
}

static void count_braces(const char *line, int *opens, int *closes)
{
	*opens = 0;
	*closes = 0;
	for (const char *p = line; *p; p++) {
		if (*p == '{')
			(*opens)++;
		else if (*p == '}')
			(*closes)++;
	}
}

static Menu *parse_grub_cfg(const char *path)
{
	FILE *fp = fopen(path, "r");
	Menu *root;
	Menu *stack[64];
	int submenu_brace_at[64] = { 0 };
	int brace_level = 0;
	int sp = 1;
	char *line = NULL;
	size_t capacity = 0;

	if (!fp) {
		perror(path);
		return NULL;
	}

	root = menu_new("ROOT", 1);
	stack[0] = root;

	while (getline(&line, &capacity, fp) != -1) {
		const char *trimmed = ltrim(line);
		int opens;
		int closes;

		count_braces(trimmed, &opens, &closes);
		if (strncmp(trimmed, "submenu", 7) == 0) {
			char *title = extract_quoted_title(trimmed);

			if (title) {
				Menu *submenu;

				if (sp == 64) {
					fprintf(stderr,
						"submenu nesting too deep\n");
					free(title);
					break;
				}
				submenu = menu_new(title, 1);
				free(title);
				menu_add_child(stack[sp - 1], submenu);
				submenu_brace_at[sp] = brace_level + opens;
				stack[sp++] = submenu;
			}
		} else if (strncmp(trimmed, "menuentry", 9) == 0) {
			char *title = extract_quoted_title(trimmed);

			if (title) {
				menu_add_child(stack[sp - 1],
					       menu_new(title, 0));
				free(title);
			}
		}

		brace_level += opens - closes;
		if (brace_level < 0)
			brace_level = 0;
		while (sp > 1 && brace_level < submenu_brace_at[sp - 1])
			sp--;
	}

	free(line);
	fclose(fp);
	return root;
}

static char *build_target(char **parents, size_t depth, const char *title)
{
	size_t length = strlen(title) + 1;
	char *target;

	for (size_t i = 0; i < depth; i++)
		length += strlen(parents[i]) + 1;

	target = xmalloc(length);
	target[0] = '\0';
	for (size_t i = 0; i < depth; i++) {
		strcat(target, parents[i]);
		strcat(target, ">");
	}
	strcat(target, title);
	return target;
}

static void entry_list_add(EntryList *list, const char *title, char *target,
			   size_t depth)
{
	Entry *entry;

	list->items =
		xrealloc(list->items, (list->count + 1) * sizeof(*list->items));
	entry = &list->items[list->count++];
	entry->title = xstrdup(title);
	entry->target = target;
	entry->depth = depth;
}

static void flatten_entries(const Menu *menu, char **parents, size_t depth,
			    EntryList *list)
{
	for (size_t i = 0; i < menu->child_count; i++) {
		const Menu *child = menu->children[i];

		if (child->is_submenu) {
			parents[depth] = child->title;
			flatten_entries(child, parents, depth + 1, list);
			continue;
		}
		entry_list_add(list, child->title,
			       build_target(parents, depth, child->title),
			       depth);
	}
}

static EntryList entry_list_new(const Menu *root)
{
	EntryList list = { 0 };
	char *parents[64];

	flatten_entries(root, parents, 0, &list);
	return list;
}

static void entry_list_free(EntryList *list)
{
	for (size_t i = 0; i < list->count; i++) {
		free(list->items[i].title);
		free(list->items[i].target);
	}
	free(list->items);
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
		case '\b':
			fputs("\\b", stdout);
			break;
		case '\f':
			fputs("\\f", stdout);
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

static void print_entries(const EntryList *list)
{
	for (size_t i = 0; i < list->count; i++)
		printf("%zu) %*s%s\n", i + 1, (int)(list->items[i].depth * 2),
		       "", list->items[i].title);
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

static int boot_entry(const EntryList *list, size_t index)
{
	char *grub_reboot[] = { "grub-reboot", list->items[index].target,
				NULL };
	char *grub_env[] = { "grub-editenv", "list", NULL };
	char *reboot[] = { "reboot", NULL };
	int rc;

	printf("Setting next boot entry to:\n  %s\n",
	       list->items[index].target);
	rc = run_cmd(grub_reboot);
	if (rc != 0) {
		fprintf(stderr, "grub-reboot failed (exit code %d)\n", rc);
		return rc ? rc : EXIT_FAILURE;
	}

	(void)run_cmd(grub_env);
	fflush(stdout);
	rc = run_cmd(reboot);
	if (rc != 0)
		fprintf(stderr, "reboot failed (exit code %d)\n", rc);
	return rc ? rc : EXIT_SUCCESS;
}

static int read_choice(size_t count)
{
	char buffer[128];

	for (;;) {
		char *end;
		long choice;

		printf("Choose [1-%zu] (0 = cancel): ", count);
		fflush(stdout);
		if (!fgets(buffer, sizeof(buffer), stdin))
			return -1;

		errno = 0;
		choice = strtol(buffer, &end, 10);
		if (errno || end == buffer) {
			puts("Please enter a number.");
			continue;
		}
		if (choice == 0)
			return 0;
		if (choice > 0 && (size_t)choice <= count)
			return (int)choice;
		puts("Out of range. Try again.");
	}
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

static void usage(const char *program)
{
	fprintf(stderr, "Usage: %s [--list | --boot INDEX]\n", program);
}

int main(int argc, char **argv)
{
	Menu *root = parse_grub_cfg("/boot/grub/grub.cfg");
	EntryList entries;
	int rc = EXIT_SUCCESS;

	if (!root)
		return EXIT_FAILURE;
	entries = entry_list_new(root);

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
		if (geteuid() != 0) {
			fprintf(stderr,
				"Boot selection requires root privileges.\n");
			rc = EXIT_FAILURE;
			goto out;
		}
		rc = boot_entry(&entries, index);
		goto out;
	}

	if (argc != 1) {
		usage(argv[0]);
		rc = EXIT_FAILURE;
		goto out;
	}

	if (entries.count == 0) {
		puts("No GRUB entries found.");
		rc = EXIT_FAILURE;
		goto out;
	}
	print_entries(&entries);
	if (geteuid() != 0) {
		fprintf(stderr, "Boot selection requires root privileges.\n");
		rc = EXIT_FAILURE;
		goto out;
	}

	int choice = read_choice(entries.count);
	if (choice > 0)
		rc = boot_entry(&entries, (size_t)choice - 1);
	else if (choice < 0)
		rc = EXIT_FAILURE;

out:
	entry_list_free(&entries);
	menu_free(root);
	return rc;
}
