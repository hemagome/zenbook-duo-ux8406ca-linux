#include <errno.h>
#include <hidapi.h>
#include <stdio.h>
#include <string.h>

#define ASUS_VENDOR_ID 0x0b05
#define UX8406CA_KEYBOARD_ID 0x1bf2
#define CONTROL_INTERFACE 4

static void usage(const char *program) {
    fprintf(stderr, "Usage: %s media|function|listen\n", program);
}

int main(int argc, char **argv) {
    unsigned char report[16] = {
        0x5a, 0xd0, 0x4e, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    struct hid_device_info *devices = NULL;
    struct hid_device_info *item = NULL;
    hid_device *keyboard = NULL;
    const char *mode;
    int result = 1;

    if (argc != 2) {
        usage(argv[0]);
        return 2;
    }

    mode = argv[1];
    if (strcmp(mode, "media") == 0) {
        report[3] = 0x00;
    } else if (strcmp(mode, "function") == 0) {
        report[3] = 0x01;
    } else if (strcmp(mode, "listen") != 0) {
        usage(argv[0]);
        return 2;
    }

    if (hid_init() != 0) {
        fprintf(stderr, "ux8406ca-fn-send: hidapi initialization failed\n");
        return 1;
    }

    devices = hid_enumerate(ASUS_VENDOR_ID, UX8406CA_KEYBOARD_ID);
    for (item = devices; item != NULL; item = item->next) {
        if (item->interface_number != CONTROL_INTERFACE)
            continue;
        keyboard = hid_open_path(item->path);
        if (keyboard == NULL) {
            fprintf(stderr,
                    "ux8406ca-fn-send: cannot open ASUS 0b05:1bf2 interface 4; "
                    "check the udev rule and reconnect the keyboard\n");
            result = 1;
            goto out;
        }
        break;
    }

    if (keyboard == NULL) {
        fprintf(stderr,
                "ux8406ca-fn-send: docked ASUS 0b05:1bf2 interface 4 not found\n");
        result = 3;
        goto out;
    }

    if (strcmp(mode, "listen") == 0) {
        unsigned char input[64];
        int length;

        while ((length = hid_read(keyboard, input, sizeof(input))) >= 0) {
            if (length >= 2 && input[0] == 0x5a && input[1] == 0x4e) {
                puts("toggle");
                fflush(stdout);
            }
        }
        fwprintf(stderr, L"ux8406ca-fn-send: HID listener ended: %ls\n",
                 hid_error(keyboard));
        result = 4;
        goto out;
    }

    if (hid_send_feature_report(keyboard, report, sizeof(report)) < 0) {
        fwprintf(stderr, L"ux8406ca-fn-send: feature report failed: %ls\n",
                 hid_error(keyboard));
        result = 1;
        goto out;
    }

    printf("ux8406ca-fn-send: applied %s-default mode\n", mode);
    result = 0;

out:
    if (keyboard != NULL)
        hid_close(keyboard);
    hid_free_enumeration(devices);
    hid_exit();
    return result;
}
