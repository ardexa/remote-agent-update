#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <sys/types.h>
#include <sys/stat.h>

using namespace std;

int main(int argc, char** argv) {
    int error = 0;

    if (argc != 2) {
        cout << "You must pass a single argument which is the process to execute" << endl;
        exit(1);
    }

    string command(argv[1]);
    string execCommand = "exec " + command;

    pid_t pid = fork();
    if(pid == 0) {
        // Child:
        // 1. Become process leader
        pid_t leader = setsid();
        if (leader == -1) {
            // fail!
            error = 1;
            return error;
        }

        // 2. Leave the cgroup (systemd)
        // The only way I've found to leave a cgroup is to make sure the
        // destination cgroup in within the same cgroup hierarcy
        // i.e. name=systemd. Attempting to create a new cgroup in, say, 'cpu'
        // won't work.
        fstream cgroup;
        string cgroup_dir = "/sys/fs/cgroup/systemd/system.slice/ardexa.disown";

        // ignore the return value
        mkdir(cgroup_dir.c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
        // if system has cgroups, move out of our current cgroup otherwise systemd will still find us
        cgroup.open((cgroup_dir + "/cgroup.procs").c_str(), fstream::out | fstream::trunc);
        if (cgroup) {
            cout << "moving cgroup..." << endl;
            cgroup << "0" << endl;
            cgroup.close();
        }

        // 3. Close all file handles so that the Ardexa agent will mark us complete
        fflush(stdout);
        fclose(stdout);
        fclose(stderr);

        // 4. Execute the given command
        execl("/bin/sh", "sh", "-c", execCommand.c_str(), NULL);
        exit(127);
    } else if(pid == -1) {
        cout << "ERR! Failed to fork child process" << endl;
        error = 1;
    }
    // Parent: sleep and exit
    sleep(2);
    return error;
}
