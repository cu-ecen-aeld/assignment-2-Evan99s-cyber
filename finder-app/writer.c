#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>

int main(int argc, char *argv[]) {
	openlog("writer", LOG_PID, LOG_USER);

	if (argc != 3) {
		syslog(LOG_ERR, "Invalid number of arguments: %d", argc);
		fprintf(stderr, "Usage: %s <writefile> <writestr>\n", argv[0]);
		closelog();
		return 1;
	}

	const char *writefile = argv[1];
	const char *writestr =  argv[2];

	FILE *fp = fopen(writefile, "w");
	if (!fp) {
		syslog(LOG_ERR, "Error opening file %s", writefile);
		closelog();
		return 1;
	}

	syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile);
	fprintf(fp, "%s", writestr);
	fclose(fp);

	closelog();
	return 0;
}
