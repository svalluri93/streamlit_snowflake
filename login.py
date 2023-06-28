import streamlit as st
import snowflake.connector



@st.cache_resource(show_spinner=False)
def init_connection():
    return snowflake.connector.connect(
        **st.secrets["snowflake"], client_session_keep_alive=True
    )



@st.cache_data(show_spinner=False,ttl=600)
def run_query(query):
    conn = init_connection()
    with conn.cursor() as cur:
        cur.execute(query)
        return cur.fetchall()
    
# Function to authenticate user login
def authenticate(username, password):
    # Perform authentication logic
    # Return True if login is successful, False otherwise
    query = '''SELECT * from STREAMLIT.AUTHENTICATION.USER where username = ''' + "'" + username + "'" + '''and password = ''' +"'"+ password +"'"
    #rows = run_query(f'''SELECT * from STREAMLIT.AUTHENTICATION.USER where username = %s and password = %s ''',(username,password))
    rows = run_query(query)

    if len(rows) > 0:
        #for row in rows:
            #st.write(f"{row[0]} has a :{row[1]}:")
        return True
    else:
        return False
    

def main():
# Login form
    
    st.set_page_config(
    layout="wide",
    page_title="classifAIr",
    page_icon="💡",
    )
    st.image('./images/logo-removebg-preview.png')
    username = st.text_input("Username")
    password = st.text_input("Password", type="password")

# Check if login button is clicked
    if st.button("Login"):
    # Call the authenticate function
        if authenticate(username, password):
            st.success("Login successful!")
        # Display the content after successful login
            st.session_state["login_token"] = True
            st.write("You can now navigate to classifAIr page!")

        else:
            st.error("Invalid credentials. Please try again.")
            st.session_state["login_token"] = False

if __name__ == "__main__":
    main()