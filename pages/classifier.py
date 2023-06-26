import streamlit as st
import pandas as pd
import openai
import csv
import pandas
import os
from tqdm import tqdm

openai.api_key = st.secrets["openai"]["OPENAI_API_KEY"]

def chat(system, user_assistant):
  assert isinstance(system, str), "`system` should be a string"
  assert isinstance(user_assistant, list), "`user_assistant` should be a list"
  system_msg = [{"role": "system", "content": system}]
  user_assistant_msgs = [
      {"role": "assistant", "content": user_assistant[i]} if i % 2 else {"role": "user", "content": user_assistant[i]}
      for i in range(len(user_assistant))]

  msgs = system_msg + user_assistant_msgs
  response = openai.ChatCompletion.create(model="gpt-3.5-turbo",
                                          messages=msgs,
                                          temperature=0,  # Control the randomness of the generated response
                                          n=1,  # Generate a single response
                                          stop=None )
  status_code = response["choices"][0]["finish_reason"]
  assert status_code == "stop", f"The status code was {status_code}."
  return response["choices"][0]["message"]["content"]


def translate(df):
        
        progress_bar = st.progress(0)
        status_count = st.empty()
        processed_rows = 0
        #for index, row in df.iterrows():
        for index, row in tqdm(df.iterrows(), total=len(df)):
            input_line = row['INPUT']
            response_fn_test = chat(''' You are a language translator. If the input sentence belongs to english language then do not translate it.
            Don’t justify your answers. Don’t give information not mentioned in the CONTEXT INFORMATION.
             Don't give subheadings. only provide translated output''',['''translate the statement - ''' + '''"''' + input_line + '''"'''+ '''. 
         '''])
            #st.write(f"translated output: {response_fn_test}")
            #row['TRANSLATION'] = response_fn_test
            df.at[index, 'TRANSLATION'] = response_fn_test.replace('"', '')
            processed_rows += 1
            progress_bar.progress((index + 1) / len(df))
            status_count.write(f"Processing row {processed_rows}/{len(df)}")
        progress_bar.empty()
        status_count.empty()

        df_final = classify(df)
        #st.write(df)
        return df_final

def classify(df):
        progress_bar = st.progress(0)
        status_count = st.empty()
        processed_rows = 0
        #for index, row in df.iterrows():
        for index, row in tqdm(df.iterrows(), total=len(df)):
            input_line = row['INPUT']
            response_fn_test = chat(''' You are a language classifier.
        below are the only list of categories available to you and you must only use any one of the below categories to classify:
        1.) Acknowledgement/non receipt of statement
        2.) Alteration/modification required
        3.) Auto debit activated without customer consent
        4.) Auto debit deactivated without customer consent
        5.) Dissatisfied with alternate mode of payment
        6.) Dissatisfied with renewal premium payment procedure
        7.) Dissatisfied with repetative calls/SMS
        8.) Dissatisfied with Repetative calls / SMS
        9.) Grievance pertaining to Online premium payment 
        10.) Happy with Branch/bank staff
        11.) Happy with communication service
        12.) Happy with Agent Service
        13.) Happy with Plan/product features
        14.) Happy with advance intimation of Renewal premium payment
        15.) Happy with Easy Premium payment options
        16.) Happy with Hassle free premium payment process
        17.) Service deficiency at branch/bank
        18.) Website is not working
        19.) Unit Statement Required
        20.) Unhappy with mandate/bank charges
        21.) Satisfied with Overall services 

 
        only provide classified category name as output. If statement cannot be classified give output as "unknown".
        Don’t justify your answers.Don't give subheadings. Don’t give information not mentioned in the CONTEXT INFORMATION.
        
        ''',['''classify the statement - ''' + input_line ])
            #st.write(f"translated output: {response_fn_test}")
            #row['TRANSLATION'] = response_fn_test
            df.at[index, 'CATEGORY'] = response_fn_test.replace('"', '')
            processed_rows += 1
            progress_bar.progress((index + 1) / len(df))
            status_count.write(f"Processing row {processed_rows}/{len(df)}")
        progress_bar.empty()
        status_count.empty()
        #st.write(df2)
        return df

def main():
    st.title("Text Classifier")
    #"st.session_state object:",st.session_state

    if st.session_state.get("login_token") != True:
        st.error("You need login to access this page.")
        st.stop()

    # File upload section
    uploaded_file = st.file_uploader("Upload a file csv/txt", type=["csv","txt"])

    # Display file content
    if uploaded_file is not None:
        try:
            choice = st.radio("Header present in file?", ("Yes", "No"))
            if choice == 'Yes':
                df = pd.read_csv(uploaded_file,header=0,names=["INPUT"])
                st.text("File Contents:")
                st.write(df)
            else:
                df = pd.read_csv(uploaded_file,names=["INPUT"])
                st.text("File Contents:")
                st.write(df)
                
        except Exception as e:
            st.error(f"Error: {e}")
    
    button_pressed = st.button("Translate & Classify")

    if button_pressed:
        df2 = translate(df)
        st.write(df2)
        st.download_button(label="Download", data=df2.to_csv(index=False,encoding='utf-8-sig'), file_name='classified_ouput.csv')
        #st.download_button(label="Download", data=df2.to_csv('classify_output.csv', encoding='utf-8-sig', index=False),mime='text/csv')

if __name__ == "__main__":
    main()