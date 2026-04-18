CC = $(CROSS_COMPILE)gcc
CFLAGS = -Wall -Werror

TARGET = writer
OBJS = writer.o

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS)

clean:
	rm -f $(TARGET) $(OBJS)
