import base64
import json
import os
#from dotenv import load_dotenv
import boto3
import click
from botocore.exceptions import ClientError
import streamlit as st
import uuid

#load_dotenv()

#AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
#AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")

AWS_ACCESS_KEY_ID = st.secrets["aws_keys"]["AWS_ACCESS_KEY_ID"]
AWS_SECRET_ACCESS_KEY = st.secrets["aws_keys"]["AWS_SECRET_ACCESS_KEY"]



def inv_agnt(agent_id, agent_alias_id, session_id, prompt):
    try:
        client = boto3.session.Session().client(service_name="bedrock-agent-runtime",region_name='us-east-1',aws_access_key_id=AWS_ACCESS_KEY_ID,aws_secret_access_key=AWS_SECRET_ACCESS_KEY)
        # See https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/bedrock-agent-runtime/client/invoke_agent.html
        response = client.invoke_agent(
            agentId=agent_id,
            agentAliasId=agent_alias_id,
            enableTrace=True,
            sessionId=session_id,
            inputText=prompt,
        )

        output_text = ""
        trace = {}

        for event in response.get("completion"):
            # Combine the chunks to get the output text
            if "chunk" in event:
                chunk = event["chunk"]
                output_text += chunk["bytes"].decode()

            # Extract trace information from all events
            if "trace" in event:
                for trace_type in ["preProcessingTrace", "orchestrationTrace", "postProcessingTrace"]:
                    if trace_type in event["trace"]["trace"]:
                        if trace_type not in trace:
                            trace[trace_type] = []
                        trace[trace_type].append(event["trace"]["trace"][trace_type])

            # TODO: handle citations/references

    except ClientError as e:
        raise

    return {
        "output_text": output_text,
        "trace": trace
    }

def init_state():
    st.session_state.session_id = str(uuid.uuid4())
    st.session_state.messages = []
    st.session_state.trace = {}



def main():

    st.set_page_config(page_title="Chatbot", layout="wide")
    st.title("HDFC Chatbot")
    if len(st.session_state.items()) == 0:
        init_state()
    
    with st.sidebar:
        if st.button("Reset Session"):
            init_state()

    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.write(message["content"])

    if prompt := st.chat_input():
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.write(prompt)

        with st.chat_message("assistant"):
            placeholder = st.empty()
            #placeholder.markdown("...")
            with st.spinner('Generating response...'):

            
                response = inv_agnt(
                "KMTJ6EKQIE",
                "TSTALIASID",
                st.session_state.session_id,
                prompt
                )
            placeholder.markdown(response["output_text"])
            st.session_state.messages.append({"role": "assistant", "content": response["output_text"]})
            st.session_state.trace = response["trace"]

    trace_type_headers = {
    "preProcessingTrace": "Pre-Processing",
    "orchestrationTrace": "Orchestration",
    "postProcessingTrace": "Post-Processing"
        }
    trace_info_types = ["invocationInput", "modelInvocationInput", "modelInvocationOutput", "observation", "rationale"]

    # Sidebar section for trace
    with st.sidebar:
        st.title("Trace")

        # Show each trace types in separate sections
        for trace_type in trace_type_headers:
            st.subheader(trace_type_headers[trace_type])

            # Organize traces by step similar to how it is shown in the Bedrock console
            if trace_type in st.session_state.trace:
                trace_steps = {}
                for trace in st.session_state.trace[trace_type]:
                    # Each trace type and step may have different information for the end-to-end flow
                    for trace_info_type in trace_info_types:
                        if trace_info_type in trace:
                            trace_id = trace[trace_info_type]["traceId"]
                            if trace_id not in trace_steps:
                                trace_steps[trace_id] = [trace]
                            else:
                                trace_steps[trace_id].append(trace)
                            break

                # Show trace steps in JSON similar to the Bedrock console
                for step_num, trace_id in enumerate(trace_steps.keys(), start=1):
                    with st.expander("Trace Step " + str(step_num), expanded=False):
                        for trace in trace_steps[trace_id]:
                            trace_str = json.dumps(trace, indent=2)
                            st.code(trace_str, language="json", line_numbers=trace_str.count("\n"))
            else:
                st.text("None")


if __name__ == "__main__":
    main()
    #client = boto3.client('bedrock-agent',region_name='us-east-1',aws_access_key_id=AWS_ACCESS_KEY_ID,aws_secret_access_key=AWS_SECRET_ACCESS_KEY)
#
    #response = client.list_agents(maxResults=20)
    #print(response)

