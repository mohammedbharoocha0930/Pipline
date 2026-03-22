/*
 * ===============================================================================
 * MULTI-THREADED NUMBER PROCESSING PIPELINE - HEADER FILE
 * ⚠ Do not modify this file contents!
 * ===============================================================================
 * 
 * This header defines all data structures, constants, and function prototypes
 * for the parallel number processing pipeline assignment.
 * 
 * ===============================================================================
 */

#ifndef PIPELINE_H
#define PIPELINE_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <pthread.h>
#include <semaphore.h>


/* ========================================================================================*/
/* CONSTANTS */
/* ========================================================================================*/

#define NUM_GENERATORS 3        // Fixed number of generator threads
#define NUM_PROCESSORS 3        // Fixed number of processor threads
#define BUFFER_SIZE 10          // Number of slots in each bounded buffer
#define MAX_N 100000            // Maximum value of N

/* ========================================================================================*/
/* DATA STRUCTURES */
/* ========================================================================================*/

/**
 * @brief Represents a number with its sequence ID
 */
typedef struct {
    int number;      // The actual number (input or result)
    int id;          // Sequence number (0, 1, 2, ... N-1)
} NumberData;

/**
 * @brief Bounded buffer structure for producer-consumer synchronization
 * 
 * This implements a circular buffer with counting semaphores for signaling
 * and mutex for mutual exclusion.
 */
typedef struct {
    NumberData buffer[BUFFER_SIZE];   // Array of numbers (circular buffer)
    int in;                           // Index for next write position (producer)
    int out;                          // Index for next read position (consumer)
    
    // Synchronization primitives
    sem_t empty;                      // Counting semaphore: empty slots (init: BUFFER_SIZE)
    sem_t full;                       // Counting semaphore: full slots (init: 0)
    pthread_mutex_t mutex;            // Mutex: protects buffer access
} BoundedBuffer;

/* ========================================================================================*/
/* GLOBAL VARIABLES (Declared in driver.c, extern here) */
/* ========================================================================================*/

extern BoundedBuffer buffer1;        // Buffer between generators and processors
extern BoundedBuffer buffer2;        // Buffer between processors and writer

extern sem_t processor_done;         // Completion semaphore (counts finished processors)

extern int N;                        // Total numbers to process (1 to N)
extern FILE *output_file;            // Output file pointer

/* ========================================================================================*/
/* FUNCTION PROTOTYPES - PROVIDED BY DRIVER */
/* ========================================================================================*/

/**
 * @brief Write a result to output file (thread-safe, called by writer only)
 * @param data NumberData to write
 */
void write_result(NumberData data);

/* ========================================================================================*/
/* FUNCTION PROTOTYPES - STUDENTS MUST IMPLEMENT */
/* ========================================================================================*/

/**
 * @brief Initialize a bounded buffer with semaphores and mutex
 * 
 * This function must:
 * 1. Initialize the 'in' and 'out' indices to 0
 * 2. Initialize semaphore 'empty' to capacity (counts empty slots)
 * 3. Initialize semaphore 'full' to 0 (counts full slots)
 * 4. Initialize mutex for buffer protection
 * 
 * @param buf Pointer to BoundedBuffer structure
 * @param capacity Number of slots in buffer (BUFFER_SIZE = 10)
 */
void init_buffer(BoundedBuffer *buf, int capacity);

/**
 * @brief Destroy/cleanup a bounded buffer
 * 
 * This function must:
 * 1. Destroy the 'empty' semaphore
 * 2. Destroy the 'full' semaphore
 * 3. Destroy the mutex
 * 
 * @param buf Pointer to BoundedBuffer structure
 */
void destroy_buffer(BoundedBuffer *buf);

/**
 * @brief Add a number to bounded buffer (PRODUCER operation)
 * 
 * This function implements the producer side of the bounded buffer pattern.
 * It must follow this EXACT sequence:
 * 
 * 1. sem_wait(&buf->empty)              // Wait for empty slot
 * 2. pthread_mutex_lock(&buf->mutex)    // Lock buffer
 * 3. Add data to buf->buffer[buf->in]
 * 4. Update buf->in = (buf->in + 1) % BUFFER_SIZE  // Circular increment
 * 5. pthread_mutex_unlock(&buf->mutex)  // Unlock buffer
 * 6. sem_post(&buf->full)               // Signal full slot available
 * 
 * ⚠️ CRITICAL: Never call pthread_mutex_lock BEFORE sem_wait (causes deadlock)
 * 
 * @param buf Pointer to BoundedBuffer structure
 * @param data NumberData to add to buffer
 */
void buffer_add(BoundedBuffer *buf, NumberData data);

/**
 * @brief Remove a number from bounded buffer (CONSUMER operation)
 * 
 * This function implements the consumer side of the bounded buffer pattern.
 * It must follow this EXACT sequence:
 * 
 * 1. sem_wait(&buf->full)               // Wait for full slot
 * 2. pthread_mutex_lock(&buf->mutex)    // Lock buffer
 * 3. Get data from buf->buffer[buf->out]
 * 4. Update buf->out = (buf->out + 1) % BUFFER_SIZE  // Circular increment
 * 5. pthread_mutex_unlock(&buf->mutex)  // Unlock buffer
 * 6. sem_post(&buf->empty)              // Signal empty slot available
 * 
 * ⚠️ CRITICAL: Never call pthread_mutex_lock BEFORE sem_wait (causes deadlock)
 * 
 * @param buf Pointer to BoundedBuffer structure
 * @return NumberData removed from buffer
 */
NumberData buffer_remove(BoundedBuffer *buf);

/**
 * @brief Generator thread function (PRODUCER for buffer1)
 * 
 * This function runs in each generator thread and must:
 * 1. Calculate which numbers this thread should generate:
 *    - Thread 0: generates indices [0, N/3)
 *    - Thread 1: generates indices [N/3, 2*N/3)
 *    - Thread 2: generates indices [2*N/3, N)
 * 2. For each index i in range:
 *    - Create NumberData: {number = i+1, id = i}
 *    - Call buffer_add(&buffer1, data)
 * 3. Exit when done (no EOF needed - semaphores handle coordination)
 * 
 * Example: N=10
 *   Generator 0: generates {1,0}, {2,1}, {3,2}, {4,3}
 *   Generator 1: generates {5,4}, {6,5}, {7,6}
 *   Generator 2: generates {8,7}, {9,8}, {10,9}
 * 
 * @param arg Pointer to thread_id (int*)
 * @return NULL
 */
void* generator_thread(void *arg);

/**
 * @brief Processor thread function (CONSUMER + PRODUCER)
 * 
 * This function runs in each processor thread and must:
 * 1. Loop to process approximately N/3 numbers:
 *    a. Get data from buffer1: data = buffer_remove(&buffer1)
 *    b. Process: data.number = data.number * data.number (square it)
 *    c. Add result to buffer2: buffer_add(&buffer2, data)
 *    d. Stop when processed enough items (check if data.id >= N-1)
 * 2. After loop: signal completion using sem_post(&processor_done)
 * 3. Return NULL
 * 
 * Note: Each processor processes until it has done its share of N items.
 *       Use data.id to determine when to stop.
 * 
 * @param arg Pointer to thread_id (int*)
 * @return NULL
 */
void* processor_thread(void *arg);

/**
 * @brief Writer thread function (CONSUMER for buffer2)
 * 
 * This function runs in the single writer thread and must:
 * 1. Initialize expected_id = 0
 * 2. Create holding buffer for out-of-order data:
 *    - NumberData holding[MAX_N]
 *    - bool has_data[MAX_N] = {false}
 * 3. Loop to process exactly N numbers:
 *    a. Get data from buffer2: data = buffer_remove(&buffer2)
 *    b. If data.id == expected_id:
 *       - Write immediately: write_result(data)
 *       - Increment expected_id++
 *       - Check holding buffer for next expected IDs and write them
 *    c. Else (out-of-order):
 *       - Store in holding buffer: holding[data.id] = data
 *       - Mark as valid: has_data[data.id] = true
 * 4. After processing all N numbers, wait for processors to finish:
 *    - for (i = 0; i < NUM_PROCESSORS; i++)
 *        sem_wait(&processor_done)
 * 5. Return NULL
 * 
 * Note: Writer MUST write results in order (by id) even though they
 *       may arrive out-of-order from processors.
 * 
 * @param arg Unused (can be NULL)
 * @return NULL
 */
void* writer_thread_func(void *arg);

#endif // PIPELINE_H