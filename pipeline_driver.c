/**
 * ===============================================================================
 * DRIVER PROGRAM (Reads input file and prints output to terminal)
 * ===============================================================================
 */

#include "pipeline.h"

/* ========================================================================================*/
/* GLOBAL VARIABLES */
/* ========================================================================================*/

BoundedBuffer buffer1;
BoundedBuffer buffer2;

sem_t processor_done;

int N = 0;
NumberData input_array[MAX_N];  // Loaded from file in main

/* ========================================================================================*/
/* UTILITY: Print usage information */
/* ========================================================================================*/

void print_usage(const char *prog_name) {
    fprintf(stderr, "\nUsage: %s <input_file>\n", prog_name);
    fprintf(stderr, "Example: %s Testing/Testcases/input1.txt\n\n", prog_name);
}

/* ========================================================================================*/
/* Load input file into input_array[] */
/* ========================================================================================*/

bool load_input_file(const char *filename) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        perror("Error opening input file");
        return false;
    }

    int value;
    N = 0;
    while (fscanf(file, "%d", &value) == 1) {
        if (N >= MAX_N) {
            fprintf(stderr, "Error: Too many inputs (max %d)\n", MAX_N);
            fclose(file);
            return false;
        }
        input_array[N].number = value;
        input_array[N].id = N;
        N++;
    }

    fclose(file);

    if (N == 0) {
        fprintf(stderr, "Error: Input file is empty or invalid.\n");
        return false;
    }

    return true;
}

/* ========================================================================================*/
/* Writer output function (called by writer thread) */
/* ========================================================================================*/

void write_result(NumberData data) {
    printf("Input: %d, Result: %d\n", data.id + 1, data.number);
    fflush(stdout);
}

/* ========================================================================================*/
/* MAIN FUNCTION */
/* ========================================================================================*/

int main(int argc, char *argv[]) {
    if (argc != 2) {
        print_usage(argv[0]);
        return EXIT_FAILURE;
    }

    const char *input_file = argv[1];
    if (!load_input_file(input_file)) {
        return EXIT_FAILURE;
    }

    // Display config
    printf("====================================================\n");
    printf("Input source         : %s\n", input_file);
    printf("Numbers to process   : %d\n", N);
    printf("Generator threads    : %d\n", NUM_GENERATORS);
    printf("Processor threads    : %d\n", NUM_PROCESSORS);
    printf("Writer threads       : 1\n");
    printf("Buffer size          : %d\n", BUFFER_SIZE);
    printf("====================================================\n\n");

    // Initialize buffers and semaphore
    init_buffer(&buffer1, BUFFER_SIZE);
    init_buffer(&buffer2, BUFFER_SIZE);
    sem_init(&processor_done, 0, 0);

    // Create threads
    pthread_t g_threads[NUM_GENERATORS];
    pthread_t p_threads[NUM_PROCESSORS];
    pthread_t writer;

    int g_ids[NUM_GENERATORS];
    int p_ids[NUM_PROCESSORS];

    for (int i = 0; i < NUM_GENERATORS; i++) {
        g_ids[i] = i;
        pthread_create(&g_threads[i], NULL, generator_thread, &g_ids[i]);
    }

    for (int i = 0; i < NUM_PROCESSORS; i++) {
        p_ids[i] = i;
        pthread_create(&p_threads[i], NULL, processor_thread, &p_ids[i]);
    }

    pthread_create(&writer, NULL, writer_thread_func, NULL);

    // Join all threads
    for (int i = 0; i < NUM_GENERATORS; i++) {
        pthread_join(g_threads[i], NULL);
    }

    for (int i = 0; i < NUM_PROCESSORS; i++) {
        pthread_join(p_threads[i], NULL);
    }

    pthread_join(writer, NULL);

    // Cleanup
    destroy_buffer(&buffer1);
    destroy_buffer(&buffer2);
    sem_destroy(&processor_done);

    return EXIT_SUCCESS;
}
