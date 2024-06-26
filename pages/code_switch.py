import re
import streamlit as st
import pandas as pd
import openai

from openai import AzureOpenAI

client = AzureOpenAI(
  azure_endpoint = st.secrets["azure_openai"]["AZURE_OPENAI_ENDPOINT"], 
  api_key=st.secrets["azure_openai"]["AZURE_OPENAI_KEY"],  
  api_version="2024-02-15-preview"
)

sql_server_to_snowflake_prompt = """
You are a code converter.
You MUST convert SQL Server compatible stored procedures into SNOWFLAKE SQL SCRIPTING with language as SQL.

Rules you MUST follow are given below.
<rules>
1.) you MUST provide only the converted code as output
2.) DO NOT EXPLAIN the code 
3.) DO NOT ENCLOSE the output in any tags
</rules>

"""

sql_server_to_redshift_prompt = """
You are a code converter.
You MUST convert SQL Server compatible stored procedures into Redshift compatible stored procedures.

Rules you MUST follow are given below.
<rules>
1.) you MUST provide only the converted code as output
2.) DO NOT EXPLAIN the code 
3.) DO NOT ENCLOSE the output in any tags
</rules>

"""


def open_ai_chat(prompt,user_assistant):

    # This is set to `azure`
    #openai.api_type = 'azure'
    # The API key for your Azure OpenAI resource.
    #openai.api_key = st.secrets["azure_openai"]["AZURE_OPENAI_KEY"]
    # The base URL for your Azure OpenAI resource. e.g. "https://<your resource name>.openai.azure.com"
    #openai.api_base = st.secrets["azure_openai"]["AZURE_OPENAI_ENDPOINT"]
    # Currently Chat Completion API have the following versions available: 2023-03-15-preview
    #openai.api_version = '2023-05-15'
    
    assert isinstance(user_assistant, list), "`user_assistant` should be a list"
    system_msg = [{"role": "system", "content": prompt}]

    user_assistant_msgs = [
      {"role": "assistant", "content": user_assistant[i]} if i % 2 else {"role": "user", "content": user_assistant[i]}
      for i in range(len(user_assistant))]

    msgs = system_msg + user_assistant_msgs

    try:
        response = client.chat.completions.create(
                  model='gpt-4o',
                  messages=msgs,
                  temperature=0,  # Control the randomness of the generated response
                  n=1,  # Generate a single response
                  stop=None
                )
    

        return response.choices[0].message.content
    
    except openai.AuthenticationError as e:
        # Handle Authentication error here, e.g. invalid API key
        print(f"OpenAI API returned an Authentication Error: {e}")

    except openai.APIConnectionError as e:
        # Handle connection error here
        print(f"Failed to connect to OpenAI API: {e}")

    except openai.BadRequestError as e:
        # Handle connection error here
        print(f"Invalid Request Error: {e}")

    except openai.RateLimitError as e:
        # Handle rate limit error
        print(f"OpenAI API request exceeded rate limit: {e}")

    except openai.InternalServerError as e:
        # Handle Service Unavailable error
        print(f"Service Unavailable: {e}")

    except openai.APITimeoutError as e:
        # Handle request timeout
        print(f"Request timed out: {e}")

    except openai.APIError as e:
        # Handle API error here, e.g. retry or log
        print(f"OpenAI API returned an API Error: {e}")

def btn_callbk():
    st.session_state.edflg = not st.session_state.edflg

def build_input(source_option,target_option):

    #st.write(source_option)
    #st.write(target_option)

    if source_option is None or target_option is None:
        st.error('Please select source and target technology')
        inp_prompt = st.text_area(label="current prompt",value='NA',height = 200, disabled=st.session_state.edflg)
    if source_option == 'SQL Server' and target_option == 'Snowflake':
        inp_prompt = st.text_area(label="current prompt",value=sql_server_to_snowflake_prompt,height = 200, disabled=st.session_state.edflg)
    if source_option == 'SQL Server' and target_option == 'Redshift':
        inp_prompt = st.text_area(label="current prompt",value=sql_server_to_redshift_prompt,height = 200, disabled=st.session_state.edflg)
    if st.button(label="Edit prompt" if st.session_state.edflg else "save", on_click=btn_callbk, key="launch",type="primary"):
        st.session_state.disabled=True
    return inp_prompt

if __name__ == "__main__":

    st.set_page_config(
    page_title="CodeSwitch",
    page_icon="🧊",
    layout="wide",
    #initial_sidebar_state="expanded",
    #menu_items={
        #'Get Help': 'https://www.extremelycoolapp.com/help',
        #'Report a bug': "https://www.extremelycoolapp.com/bug",
       # 'About': "# This is a header. This is an *extremely* cool app!"
              # }
        )

    st.title("CodeSwitch")

    # Initialize the chat messages history

    if "edflg" not in st.session_state:
        st.session_state.edflg = False

    source_col, target_col = st.columns(2)

    with source_col:
        source_option = st.selectbox(
        'Source technology',
        options= ['SQL Server'],index=None)

    with target_col:
        target_option = st.selectbox(
        'Target technology',
        ('Snowflake','Redshift'),index=None)

    #if source_option == '' and target_option == '':
    edited_prompt = build_input(source_option,target_option)

    #st.text_area('current prompt',value = prompt,height=400,disabled=True)
    #if st.button("Edit prompt", type="primary"):


    col1, col2 = st.columns(2)

    with col1:

        inp_txt = st.text_area('paste your code below',height=400)
        #st.button("Reset", type="primary")
    if st.button("convert", type="primary"):
        with col2:
            response_fn_test = open_ai_chat(edited_prompt, ['''input is  - ''' + '''"''' + inp_txt + '''"'''+ '''. 
         '''])
            conv_txt = st.text_area('converted code',value = response_fn_test,height=400,disabled=True)