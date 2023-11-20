import time
import streamlit as st
import pandas as pd
import numpy as np
import os
import subprocess as sp
from io import StringIO
import uuid  

st.title('IICS Codeploy')

print(os.environ)

def follow(thefile):
    '''generator function that yields new lines in a file
     '''
    # seek the end of the file
    thefile.seek(0, os.SEEK_END)
    #print('in follow')
    # start infinite loop
    while True:
        # read last line of file
        line = thefile.readline()
        # sleep if file hasn't been updated
        if not line:
            time.sleep(0.1)
            continue

        yield line

uuid=uuid.uuid1().hex
uploaded_file = st.file_uploader("Choose a file containing details of objects to be deployed")
if uploaded_file is not None:
    # To read file as bytes:
    bytes_data = uploaded_file.getvalue()
    #st.write(bytes_data)

    # To convert to a string based IO:
    stringio = StringIO(uploaded_file.getvalue().decode("utf-8"))
    #st.write(stringio)

    # To read file as string:
    string_data = stringio.read()
    #st.write(string_data)

    dataframe = pd.read_csv(uploaded_file)
    #st.write(dataframe)
    dataframe.to_csv('../Config/deployment_template_' + uuid + '.txt', index = False, quotechar = '"')

src_usernm_inp = st.text_input('Provide source org username..')
src_pwd_inp = st.text_input(label = 'Provide source org password..', type = "password")
is_src_tgt_creds_same = st.text_input('Is Source and Target same? [Y/N]')

log_file_name = "../Logs/iics_code_deployment_" + src_usernm_inp + "_" + uuid + ".log"

if is_src_tgt_creds_same == 'N':
    tgt_usernm_inp = st.text_input('Provide target org username..')
    tgt_pwd_inp = st.text_input(label = 'Provide target org password..', type = "password")
    if st.button('Start Deployment', type="primary"):
        shell_cmd_to_run = "sh ../Scripts/iics_code_deployment_streamlit.sh " + src_usernm_inp + " " + src_pwd_inp + " " + tgt_usernm_inp + " " + tgt_pwd_inp + " " + uuid + " &"
        st.write('Deployment begins')
        #print(sp.run([shell_cmd_to_run], capture_output = True, shell = True))
        print(sp.run(["touch " + log_file_name], shell = True))
        print(sp.run([shell_cmd_to_run], shell = True))
        logfile = open(log_file_name, "r")
        loglines = follow(logfile)
        
        with st.status('Deployment begins..') as status:
            # iterate over the generator
            for line in loglines:
                st.write(line)

                if line.find('Calling script iics_code_deployment_import_streamlit.sh to take import of IICS objects - Completed')>0:
                    break
            status.update(label="Deployment complete!", state="complete", expanded=False)
        print('completed')
    else:
        pass
else:
    shell_cmd_to_run = "sh ../Scripts/iics_code_deployment_streamlit.sh " + src_usernm_inp + " " + src_pwd_inp + " " + uuid + " &"
    if st.button('Start Deployment', type="primary"):
        st.write('Deployment begins')
        #print(sp.run([shell_cmd_to_run], capture_output = True, shell = True))
        print(sp.run(["touch " + log_file_name], shell = True))
        print(sp.run([shell_cmd_to_run], shell = True))
        
        logfile = open(log_file_name, "r")
        loglines = follow(logfile)
        
        with st.status('Deployment begins..') as status:
            # iterate over the generator
            for line in loglines:
                st.write(line)

                if line.find('Calling script iics_code_deployment_import_streamlit.sh to take import of IICS objects - Completed')>0:
                    break
            status.update(label="Deployment complete!", state="complete", expanded=False)
        print('completed')
    else:
        pass

