# webtrees-mngr.py

# import modules
import argparse
from configparser import ConfigParser

# definitions
def input_yesno(prompt: str) -> bool:
    full_prompt = f"{prompt} ([Yes]/No): "
    while True:
        answer = input(full_prompt).strip()
        if answer == "":
            return True

        answer = answer[0].lower()
        if answer == "y":
            return True
        if answer == "n":
            return False
        print("ERROR")

# main program
if __name__ == "__main__":

    # init parser
    parser = argparse.ArgumentParser(prog="webtrees-mngr.py", description="This is a tool for managing a webtrees install. It can be used to install, update, backup and remove webtrees. Please submit any issues with %(prog)s here https://github.com/Tuetenk0pp/webtrees-mngr/issues/.")
    parser.add_argument("--version", action="version", version="%(prog)s 1.0")
    parser.add_argument("action", choices=["install", "update", "remove"], help="install webtrees and all dependencies", metavar="ACTION", type=str)
    parser.add_argument("--force", action="store_true", help="use with caution")
    parser.add_argument("--config", help="optional configuration file", type=str, default="settings.ini")

    # parse arguments
    args = parser.parse_args()



    # install and setup stack
    if args.action == "install":
        print("This is an interactive install-script for webtrees.\nIt is meant for non-technical users who want to get a webtrees installation up quickly.\nThe script needs a fresh ubuntu-server install to run on.\nDo not continue if you already have a webserver and some sort of webapp installed!")
        if not input_yesno("Continue?"):
            print("aborting")
            exit(0)
        print("install success")

        # parse config
        config = ConfigParser() # init config object
        config.read(args.config) # parse file
        # now set values with user input
        # for key in keys:
            # config.get
            # config.set = input()
            # print(f"Please provide the configuration values. Press [Enter] to keep values supplied in the {args.config}") 

        file = open(args.config) # open conf file
        config.write(file, space_around_delimiters=True) # write config to file
        file.close() # close file


    # update stack
    elif args.action == "update":
        pass

    # remove stack
    else:
        pass
