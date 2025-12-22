# Bash User Management Script

## Project Description:

The "Bash User Management Script" is a Bash script designed to automate the process of creating a new user account on a Unix-like system and setting up SSH access for that user. This project aims to simplify and streamline the administrative tasks involved in user management, particularly in environments where multiple user accounts need to be provisioned quickly and consistently.

### Features:

1. **Interactive User Input:** The script prompts the administrator for essential information, such as the username, password, and SSH public key path, ensuring flexibility and customization for each new user.

2. **Secure Password Entry:** The script hides the password input while prompting the administrator, enhancing security by preventing password visibility during entry.

3. **SSH Key Management:** It automates the process of appending the provided SSH public key to the user's `authorized_keys` file, enabling secure SSH access without the need for manual configuration.

4. **Home Directory Setup:** The script copies skeleton files from `/etc/skel` to the new user's home directory, ensuring that the user has a consistent environment upon login.

5. **User Account Creation:** It adds the new user with the specified home directory and shell, simplifying the user provisioning process.

6. **Permissions Management:** The script sets appropriate ownership and permissions for the user's home directory, ensuring that the user has proper access to their files and directories.

7. **Password Setting:** It securely sets the password for the new user, ensuring that the account is properly secured upon creation.

## Implementation:

To implement the "Bash User Management Script," follow these steps:

1. **Create SSH Key:**
    ```bash
    dmitry@ubuntuserver:~/scripts$ ssh-keygen
    ```

2. **Create "scripts" folder:**
    ```bash
    dmitry@ubuntuserver:~$ mkdir scripts
    ```

3. **Create script file:**
    ```bash
    dmitry@ubuntuserver:~/scripts$ touch create_user_ssh_pub.sh
    ```

4. **Paste script code into the text editor:**
   - [create_user_ssh_pub.sh](https://github.com/DimitryZH/bash-user-management-script/blob/main/create_user_ssh_pub.sh)

![create-user-script](https://github.com/DimitryZH/bash-user-management-script/assets/146372946/87376465-ff1b-4119-bdd5-c26be19e6a73)

5. **Execute the script:**
    ```bash
    dmitry@ubuntuserver:~/scripts$ sudo bash create_user_ssh_pub.sh
    ```

6. **Enter user, password, and SSH public key path:** 
   - SSH public key path: "/home/dmitry/.ssh/id_rsa.pub"

## Results:

Below are the screenshots of the script execution with the user entering the password, login, etc., and the results of verifying the new user:

1. ![create-user-script-result_1](https://github.com/DimitryZH/bash-user-management-script/assets/146372946/af42bd90-3090-4a24-af4b-13c0d5132f2d)
2. ![create-user-script-result_2](https://github.com/DimitryZH/bash-user-management-script/assets/146372946/c8775e0d-5b6b-4471-8ced-f89d7ab2762b)
3. ![create-user-script-result_3](https://github.com/DimitryZH/bash-user-management-script/assets/146372946/77a33c85-1f10-4799-9c7e-5adc2c1dbdec)

These screenshots demonstrate the script execution process, including the input of password, login, etc., as well as the verification of the results by logging in under the new user and checking `cat /etc/passwd` and `cat /etc/group`.


## Conclusion:

The "Bash User Management Script" project aims to simplify and automate user management tasks on Unix-like systems, enhancing administrative efficiency and consistency. This project offers a reliable and user-friendly solution for system administrators and DevOps professionals. Contributions are welcome.
