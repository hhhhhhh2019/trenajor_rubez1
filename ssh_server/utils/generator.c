// логика работы ужасна, но иногда оно работает нормально

#include <stdio.h>
#include <stdlib.h>


#define MAX_LEVEL 3
#define MIN_ELEMS 2
#define MAX_ELEMS 5
#define INDENT          "    "
#define INDENT_LAST     "    "
#define INDENT_LAST_DIR "    "


const char* names[] = { // имена(кроме lab0) должны быть отсортированы
	"affusto",
	"casa",
	"charlie",
	"delta",
	"deltarune",
	"echpoch1mak",
	"hiidenkiwi",
	"juliett1",
	"kolisilmia",
	"limanul0aska",
	"pikkuhamiahiakikki",
	"rakamakaf0",
	"stazione",
	"suurtulikarpanen",
	"tappuraOhijsilaynen",
	"taykasuava",
	"undertale0",
	"yankee",
	"yoshkarola",
	"lab0"
};
#define NAMES_COUNT (sizeof(names) / sizeof(*names) - 1)
char filenames_used[NAMES_COUNT] = {0};

const char* texts[] = {
	"Выходит Троцкий из кабинета Сталина и говорит:\n\"Вот же ж сволочь усатая\". Берия это услышал и доложил Сталину.\nНа следующий день Сталин вызывает Тоцкий и Берию к себе и говорит:\n\"Вы, товарищ Троцкий, когда из моего кабинета выходили, сказали сволочь усатая.\nЭто вы кого имели ввиду?\". \"Гитлера\" - ответил Троцкий.\n\"А вы, товарищ Берия, кого имели ввиду?\"\n",
	"В вагоне сидит батюшка, напротив сидит комсомолец,\nи вдруг он решает подшутить на священно служителем.\n\"Ну что, батюшка, молитесь?\"\n\"Молимся.\"\n\"И за советскую власть молитесь?\"\n\"И за советскую власть молимся.\"\n\"Ну вы же наверное и за царскую власть молились?\"\n\"Молился.\"\n\"И как, помогло?\"\n\"Помогло: нет больше царской власти.\"\n",
	"Пасха. Брежнев идет по коридору. Ема навстречу идет чиновник и говорит:\n\"Леонид Ильич, Христос воскресе!\"\n\"Я знаю. Мне уже доложили\"\n",
	"я не знаю что еще придумать\n",
	"Идет мужчина у психбольницы. Слышит как писхи кричат:\n\"41, 41, 41...\".\nСтало ему интересто: что они там делают?\nПодошел к забору и заглянул в дырку.\nА психи ткунли ему палкой в глаз и кричат: \"42, 42, 42, 42...\"\n",
	"Два еврея возвращаются домой поздно вечером и замечают двух подозрительных субъектов вдалеке.\nИ один обращается к другому: \"Изя, предлагаю повернуть назад. Их таки двое, а мы одни.\"\n"
};
#define TEXTS_COUNT (sizeof(texts) / sizeof(*texts))


unsigned int hash(char* str) {
	unsigned int result = 0;
	for (; *str; str++)
		result += *str + 31 * result;
	return result;
}


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


void generate_file(int name, int level);
void generate_directory(int name, int level);


void generate_file(int name, int level) {
	for (int i = 0; i < level - 1; i++) {
		printf(INDENT);
	}
	printf(INDENT_LAST);

	print_permissions(rand() % 512);
	printf(" %s(файл)\n", names[name]);
}


void generate_directory(int name, int level) {
	for (int i = 0; i < level - 1; i++) {
		printf(INDENT);
	}
	if (level != 0)
		printf(INDENT_LAST_DIR);

	print_permissions(rand() % 512);
	printf(" %s(директория)\n", names[name]);

	char names_used[NAMES_COUNT] = {0};

	for (int i = 0; i < MIN_ELEMS + rand() % (MAX_ELEMS - MIN_ELEMS); i++) {
		char type = rand() % 2;

		if (level == MAX_LEVEL)
			type = 0;

		char exists_free_filename = 0;
		for (int j = 0; j < NAMES_COUNT; j++) {
			if (filenames_used[j] == 1)
				continue;
			exists_free_filename = 1;
			break;
		}

		if (!exists_free_filename)
			continue;

		int name_id;
		do { name_id = rand() % NAMES_COUNT; } while (names_used[name_id] != 0 || (type == 0 && filenames_used[name_id] != 0));
		names_used[name_id] = 1;

		if (type == 0) {
			filenames_used[name_id] = 1;

			generate_file(name_id, level + 1);
		} else {
			generate_directory(name_id, level + 1);
		}
	}
}


int main(int argc, char** argv) {
	if (argc != 2) {
		printf("Usage: %s <вариант>", argv[0]);
		return 1;
	}

	srand(hash(argv[1]));

	generate_directory(NAMES_COUNT, 0);

	printf("\n");

	for (int i = 0; i < NAMES_COUNT; i++) {
		if (filenames_used[i] == 0)
			continue;

		printf("%s: {%s}\n", names[i], texts[rand() % TEXTS_COUNT]);
	}
}
