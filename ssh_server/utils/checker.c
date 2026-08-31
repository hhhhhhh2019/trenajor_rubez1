// TODO: почитать как работет ftw и сделать через него

#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <dirent.h>


#define INDENT          "|   "
#define INDENT_LAST     "|   "
#define INDENT_LAST_DIR "|   +"


struct Node {
	char* name;
	unsigned short perms;
	char is_dir;
	size_t count;
	struct Node* nodes;
};

struct File {
	char* filename;
	char* dirname;
};

size_t files_count = 0;
struct File* files;


void print_permission(int p) {
	if (p & 4)
		printf("r");
	else
		printf("-");
	if (p & 2)
		printf("w");
	else
		printf("-");
	if (p & 1)
		printf("x");
	else
		printf("-");
}

void print_permissions(int p) {
	print_permission((p >> 6) & 0b111);
	print_permission((p >> 3) & 0b111);
	print_permission((p >> 0) & 0b111);
}


char cmp_strings(char* a, char* b) {
	while (*a != 0 && *b != 0) {
		if (*a == *b) {
			a++; b++;
			continue;
		}
		break;
	}
	return *a < *b;
}


void sort_dir(void* arr[], size_t len, size_t elem_size) {
	char tmp[elem_size];

	for (size_t i = 0; i < len; i++) {
		for (size_t j = i + 1; j < len; j++) {
			char** a = (char**)(arr + elem_size * i / sizeof(*arr));
			char** b = (char**)(arr + elem_size * j / sizeof(*arr));

			if (cmp_strings(*a, *b) == 1) continue;

			memcpy(tmp, a, elem_size);
			memcpy(a, b, elem_size);
			memcpy(b, tmp, elem_size);
		}
	}
}


struct Node readfile(char* path, char* filename) {
	char* basepath = malloc(strlen(path) + strlen(filename) + 2);
	sprintf(basepath, "%s/%s", path, filename);

	struct stat buf;
	int st = stat(basepath, &buf);

	if (st != 0) {
		fprintf(stderr, "%s\n", basepath);
		perror("stat");
		exit(errno);
	}

	struct Node node = {
		.name = filename,
		.perms = buf.st_mode & 0b111111111,
	};

	if (S_ISREG(buf.st_mode)) {
		node.is_dir = 0;
		files = realloc(files, sizeof(*files) * (++files_count));
		files[files_count - 1].filename = filename;
		files[files_count - 1].dirname = path;
		return node;
	}

	node.is_dir = 1;
	node.count = 0;
	node.nodes = malloc(0);

	DIR* dir = opendir(basepath);

	struct dirent* dirent;
	while ((dirent = readdir(dir))) {
		if (strcmp(dirent->d_name, ".") == 0)
			continue;
		if (strcmp(dirent->d_name, "..") == 0)
			continue;

		char* name = malloc(strlen(dirent->d_name) + 1);
		strcpy(name, dirent->d_name);

		node.nodes = realloc(node.nodes, sizeof(*node.nodes) * (++node.count));
		node.nodes[node.count - 1] = readfile(basepath, name);
	}

	closedir(dir);

	sort_dir((void*)node.nodes, node.count, sizeof(struct Node));

	return node;
}


void print_node(struct Node node, int level) {
	for (int i = 0; i < level - 1; i++) {
		printf(INDENT);
	}
	if (level != 0) {
		if (node.is_dir) printf(INDENT_LAST_DIR);
		else printf(INDENT_LAST);
	}

	print_permissions(node.perms);

	if (!node.is_dir) {
		printf(" %s(файл)\n", node.name);
		return;
	}

	printf(" %s(директория)\n", node.name);

	for (int i = 0; i < node.count; i++)
		print_node(node.nodes[i], level + 1);
}


int main(int argc, char** argv) {
	if (argc != 2) {
		printf("Usage: %s <путь до директории>", argv[0]);
		return 1;
	}

	files = malloc(0);

	char* dn = malloc(strlen(argv[1]) + 1);
	strcpy(dn, argv[1]);

	print_node(readfile(dirname(dn), basename(argv[1])), 0);

	printf("\n");

	sort_dir((void*)files, files_count, sizeof(*files));

	for (int i = 0; i < files_count; i++) {
		char* path = malloc(strlen(files[i].dirname) + strlen(files[i].filename) + 2);
		sprintf(path, "%s/%s", files[i].dirname, files[i].filename);

		FILE* f = fopen(path, "rb");
		fseek(f, 0, SEEK_END);
		size_t size = ftell(f);
		rewind(f);

		char* data = malloc(size);
		fread(data, size, 1, f);

		printf("%s: {%.*s}\n", files[i].filename, (int)size, data);

		free(path);
		free(data);
	}
}
