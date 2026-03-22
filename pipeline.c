/*
 * ===============================================================================

 * REQUIREMENTS:
 * - Implement bounded buffer operations with counting semaphores and mutex
 * - Implement generator thread (producer for buffer1)
 * - Implement processor thread (consumer + producer)
 * - Implement writer thread (consumer for buffer2)
 * - Use semaphores for all coordination (no manual counters)
 * - Ensure results are written in correct order (by ID)
 * - Use proper synchronization to avoid race conditions and deadlocks
 *
 *💡 CRITICAL SYNCHRONIZATION PATTERN (Bounded Buffer Algorithm)
 * PRODUCER OPERATION
 * 1. Wait until a buffer slot becomes available
 * 2. Enter the critical section protecting the buffer
 * 3. Insert the item into the buffer
 * 4. Leave the critical section
 * 5. Signal that a new item is available

 * CONSUMER OPERATION
 *  1. Wait until an item becomes available
 *  2. Enter the critical section protecting the buffer
 *  3. Remove the item from the buffer
 *  4. Leave the critical section
 *  5. Signal that a buffer slot is now free
 *
 * ⚠️ GRADING CRITERIA:
 * - Correct bounded buffer implementation
 * - Proper semaphore usage
 * - Proper mutex usage
 * - No race conditions or deadlocks
 * - Correct work distribution
 * - Writer maintains correct order
 * - Code compiles cleanly (no warnings or errors)
 */

#include "pipeline.h"

// Allow access to input array loaded in driver.c
extern NumberData input_array[MAX_N];

/* ========================================================================================
 ⚠️BUFFER MANAGEMENT FUNCTIONS - YOU MUST IMPLEMENT THESE 4 FUNCTIONS ONLY! 
=================================================================++=======================*/

/**
 * @brief Initialize a bounded buffer with semaphores and mutex
 */
void init_buffer(BoundedBuffer *buf, int capacity) {
    buf->in = 0;
    buf->out = 0;

    sem_init(&buf->empty, 0, capacity);
    sem_init(&buf->full, 0, 0);

    pthread_mutex_init(&buf->mutex, NULL);
}

/**
 * @brief Destroy/cleanup a bounded buffer
 */
void destroy_buffer(BoundedBuffer *buf) {
    sem_destroy(&buf->empty);
    sem_destroy(&buf->full);

    pthread_mutex_destroy(&buf->mutex);
}

/**
 * @brief Add a number to bounded buffer (PRODUCER operation)
 */
void buffer_add(BoundedBuffer *buf, NumberData data) {
    sem_wait(&buf->empty);

    pthread_mutex_lock(&buf->mutex);

    buf->buffer[buf->in] = data;
    buf->in = (buf->in + 1) % BUFFER_SIZE;

    pthread_mutex_unlock(&buf->mutex);

    sem_post(&buf->full);
}

/**
 * @brief Remove a number from bounded buffer (CONSUMER operation)
 */
NumberData buffer_remove(BoundedBuffer *buf) {
    NumberData data;

    sem_wait(&buf->full);

    pthread_mutex_lock(&buf->mutex);

    data = buf->buffer[buf->out];
    buf->out = (buf->out + 1) % BUFFER_SIZE;

    pthread_mutex_unlock(&buf->mutex);

    sem_post(&buf->empty);

    return data;
}


/* ========================================================================================*/
/* ⚠️ THREAD FUNCTIONS - DO NOT MODIFY */
/* ========================================================================================*/

void* generator_thread(void *arg) {
    int thread_id = *(int*)arg;
    int start = (thread_id * N) / NUM_GENERATORS;
    int end   = ((thread_id + 1) * N) / NUM_GENERATORS;

    for (int i = start; i < end; i++) {
        NumberData data = input_array[i];
        buffer_add(&buffer1, data);
    }

    return NULL;
}

void* processor_thread(void *arg) {
    int thread_id = *(int*)arg;
    int start = (thread_id * N) / NUM_PROCESSORS;
    int end   = ((thread_id + 1) * N) / NUM_PROCESSORS;

    for (int i = start; i < end; i++) {
        NumberData data = buffer_remove(&buffer1);
        data.number = data.number * data.number;
        buffer_add(&buffer2, data);
    }

    sem_post(&processor_done);
    
    return NULL;
}

void* writer_thread_func(void *arg) {
    (void)arg;

    int expected_id = 0;
    NumberData *holding = malloc(sizeof(NumberData) * MAX_N);
    bool *has_data = calloc(MAX_N, sizeof(bool));
    int received = 0;

    if (holding == NULL || has_data == NULL) {
        free(holding);
        free(has_data);
        return NULL;
    }

    while (received < N) {
        NumberData data = buffer_remove(&buffer2);

        if (data.id == expected_id) {
            write_result(data);
            expected_id++;

            while (expected_id < N && has_data[expected_id]) {
                write_result(holding[expected_id]);
                has_data[expected_id] = false;
                expected_id++;
            }
        } else {
            holding[data.id] = data;
            has_data[data.id] = true;
        }

        received++;
    }

    for (int i = 0; i < NUM_PROCESSORS; i++) {
        sem_wait(&processor_done);
    }

    free(holding);
    free(has_data);

    return NULL;
}