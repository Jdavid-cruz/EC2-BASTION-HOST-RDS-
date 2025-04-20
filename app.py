# Importo lo esencial para mi app Flask
from flask import Flask, render_template, request, redirect, url_for
import psycopg2
import os 
from psycopg2 import OperationalError

app = Flask(__name__)

# En lugar de quemar los datos de acceso a la DB en el código, uso variables de entorno.
# Mucho más seguro, sobre todo si voy a subir este archivo a GitHub.
DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST'),
    'database': os.getenv('DB_NAME'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASS'),
    'port': os.getenv('DB_PORT')
}

# Esta función se encarga de conectar con la base de datos usando la config anterior.
# Si hay algún problema, simplemente retorno None.
def get_db_connection():
    try:
        conn = psycopg2.connect(**DATABASE_CONFIG)
        return conn
    except OperationalError as e:
        print(f"Error al conectar a PostgreSQL: {e}")
        return None 

# Al iniciar la app, ejecuto esta función para asegurarme de que la tabla "users" existe.
def init_db():
    conn = get_db_connection()
    if conn is None:
        return False
    
    try:
        cursor = conn.cursor()

        # Si no existe la tabla "users", la creo con los campos que necesito
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(100) NOT NULL,
                email VARCHAR(100) NOT NULL UNIQUE,
                phone VARCHAR(20) NOT NULL,
                profession VARCHAR(100) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        return True
    
    except Exception as e:
        print(f"Error al inicializar la base de datos: {e}")
        return False
    
    finally:
        if conn:
            conn.close()

# Ruta principal, simplemente renderiza el formulario
@app.route('/')
def index():
    return render_template('index.html')

# Ruta para manejar los registros. Recibe los datos del form y los guarda en la DB.
@app.route('/register', methods=['POST'])
def register():
    username = request.form['username']
    email = request.form['email']
    phone = request.form['phone']
    profession = request.form['profession']
    
    conn = get_db_connection()
    if conn is None:
        return "Error de conexión a la base de datos", 500
    
    try:
        cursor = conn.cursor()
        
        # Inserto el nuevo usuario en la base de datos
        cursor.execute(
            "INSERT INTO users (username, email, phone, profession) VALUES (%s, %s, %s, %s)",
            (username, email, phone, profession)
        )
        
        conn.commit()
        return render_template('success.html', 
                            username=username, 
                            email=email, 
                            phone=phone, 
                            profession=profession)
    
    except Exception as e:
        conn.rollback()
        error_msg = f"Error al registrar usuario: {str(e)}"
        print(error_msg)
        return render_template('error.html', error_message=error_msg), 500
    
    finally:
        if conn:
            conn.close()

# Esta parte se ejecuta al lanzar la app. Inicializa la base de datos y arranca el servidor Flask.
# En local uso "debug=True", pero en producción iría con Gunicorn.
if __name__ == '__main__':
    if init_db():
        print("Base de datos inicializada correctamente")
        app.run(debug=True)
    else:
        print("No se pudo inicializar la base de datos")
