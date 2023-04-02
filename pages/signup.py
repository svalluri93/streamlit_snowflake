import streamlit as st

# Create a dictionary to store the user credentials
user_credentials = {}

# Define the sign-up page
def signup():
    st.title('Sign Up')
    username = st.text_input('Username')
    password = st.text_input('Password', type='password')
    confirm_password = st.text_input('Confirm Password', type='password')

    # Check if passwords match
    if password == confirm_password:
        # Add the user credentials to the dictionary
        user_credentials[username] = password
        st.button('Sign Up')
    else:
        st.error('Passwords do not match')

# Define the login page
def login():
    st.title('Log In')
    username = st.text_input('Username')
    password = st.text_input('Password', type='password')

    # Check if the username exists and if the password matches
    if username in user_credentials and user_credentials[username] == password:
        st.success('Logged in successfully')
    else:
        st.error('Incorrect username or password')

# Create the Streamlit app
st.set_page_config(page_title='Sign Up / Log In')
page = st.sidebar.radio('Navigation', ['Sign Up', 'Log In'])

# Show the appropriate page based on user selection
if page == 'Sign Up':
    signup()
else:
    login()
