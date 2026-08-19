#include <errno.h>
#include <hidapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ASUS_VENDOR_ID 0x0b05
#define UX8406CA_USB_KEYBOARD_ID 0x1bf2
#define UX8406CA_BLUETOOTH_KEYBOARD_ID 0x1bf3
#define CONTROL_INTERFACE 4
#define VENDOR_USAGE_PAGE 0xff31
#define VENDOR_USAGE 0x0076

static int is_control_collection(const struct hid_device_info *device) {
    if (device->vendor_id != ASUS_VENDOR_ID)
        return 0;
    if (device->product_id == UX8406CA_USB_KEYBOARD_ID)
        return device->interface_number == CONTROL_INTERFACE;
    if (device->product_id == UX8406CA_BLUETOOTH_KEYBOARD_ID)
        return device->usage_page == VENDOR_USAGE_PAGE &&
               device->usage == VENDOR_USAGE;
    return 0;
}

static void usage(const char *program) {
    fprintf(stderr,
            "Usage: %s media|function|listen|backlight <0|1|2|3>\n",
            program);
}

int main(int argc, char **argv) {
    unsigned char report[16] = {
        0x5a, 0xd0, 0x4e, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    struct hid_device_info *devices = NULL;
    struct hid_device_info *item = NULL;
    hid_device *keyboard = NULL;
    const char *command;
    int result = 1;

    if (argc < 2 || argc > 3) {
        usage(argv[0]);
        return 2;
    }

    command = argv[1];
    if (strcmp(command, "media") == 0 && argc == 2) {
        report[3] = 0x00;
    } else if (strcmp(command, "function") == 0 && argc == 2) {
        report[3] = 0x01;
    } else if (strcmp(command, "listen") == 0 && argc == 2) {
        /* No output report is sent in listener mode. */
    } else if (strcmp(command, "backlight") == 0 && argc == 3 &&
               strlen(argv[2]) == 1 && argv[2][0] >= '0' && argv[2][0] <= '3') {
        report[1] = 0xba;
        report[2] = 0xc5;
        report[3] = 0xc4;
        report[4] = (unsigned char)(argv[2][0] - '0');
    } else {
        usage(argv[0]);
        return 2;
    }

    if (hid_init() != 0) {
        fprintf(stderr, "ux8406ca-fn-send: hidapi initialization failed\n");
        return 1;
    }

    devices = hid_enumerate(ASUS_VENDOR_ID, 0x0000);
    for (item = devices; item != NULL; item = item->next) {
        if (!is_control_collection(item))
            continue;
        keyboard = hid_open_path(item->path);
        if (keyboard == NULL) {
            fprintf(stderr,
                    "ux8406ca-fn-send: cannot open the UX8406CA keyboard's "
                    "vendor HID collection; "
                    "check the udev rule and reconnect the keyboard\n");
            result = 1;
            goto out;
        }
        break;
    }

    if (keyboard == NULL) {
        fprintf(stderr,
                "ux8406ca-fn-send: UX8406CA keyboard control collection not found\n");
        result = 3;
        goto out;
    }

    if (strcmp(command, "listen") == 0) {
        unsigned char input[64];
        unsigned char active_command = 0x00;
        int length;

        while ((length = hid_read(keyboard, input, sizeof(input))) >= 0) {
            if (length < 2 || input[0] != 0x5a)
                continue;
            if (input[1] == 0x00) {
                active_command = 0x00;
                continue;
            }
            if (input[1] == active_command)
                continue;
            active_command = input[1];
            if (active_command == 0x4e)
                puts("toggle");
            else if (active_command == 0xc7)
                puts("backlight");
            else
                continue;
            fflush(stdout);
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

    if (strcmp(command, "backlight") == 0)
        printf("ux8406ca-fn-send: applied keyboard backlight level %s\n", argv[2]);
    else
        printf("ux8406ca-fn-send: applied %s-default mode\n", command);
    result = 0;

out:
    if (keyboard != NULL)
        hid_close(keyboard);
    hid_free_enumeration(devices);
    hid_exit();
    return result;
}
