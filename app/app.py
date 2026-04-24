from flask import Flask, render_template, request, redirect, url_for, jsonify
import os, sqlite3

app = Flask(__name__)
DB_PATH = os.environ.get("DB_PATH", "/data/formations.db")


def get_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS formations (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            titre    TEXT NOT NULL,
            duree    TEXT NOT NULL,
            niveau   TEXT NOT NULL,
            description TEXT NOT NULL
        )
    """)
    if conn.execute("SELECT COUNT(*) FROM formations").fetchone()[0] == 0:
        formations = [
            ("Développement Web Full-Stack",   "6 mois", "Débutant",      "HTML, CSS, JavaScript, React, Node.js"),
            ("DevOps & Cloud",                 "4 mois", "Intermédiaire", "Docker, Kubernetes, CI/CD, AWS"),
            ("Data Science & Machine Learning","5 mois", "Intermédiaire", "Python, Pandas, Scikit-learn, TensorFlow"),
            ("Cybersécurité",                  "4 mois", "Avancé",        "Pentesting, Cryptographie, Sécurité réseau"),
            ("Développement Mobile",           "3 mois", "Débutant",      "Flutter, React Native, iOS & Android"),
            ("Intelligence Artificielle",      "6 mois", "Avancé",        "Deep Learning, NLP, Vision par ordinateur"),
        ]
        conn.executemany(
            "INSERT INTO formations (titre, duree, niveau, description) VALUES (?,?,?,?)",
            formations
        )
    conn.commit()
    conn.close()


@app.route("/")
def index():
    init_db()
    conn = get_db()
    formations = conn.execute("SELECT * FROM formations").fetchall()
    conn.close()
    return render_template("index.html", formations=formations)


@app.route("/add", methods=["GET", "POST"])
def add_formation():
    init_db()
    error = None
    if request.method == "POST":
        titre       = request.form.get("titre", "").strip()
        duree       = request.form.get("duree", "").strip()
        niveau      = request.form.get("niveau", "").strip()
        description = request.form.get("description", "").strip()

        if not titre or not duree or not niveau or not description:
            error = "Tous les champs sont obligatoires."
        else:
            conn = get_db()
            conn.execute(
                "INSERT INTO formations (titre, duree, niveau, description) VALUES (?,?,?,?)",
                (titre, duree, niveau, description)
            )
            conn.commit()
            conn.close()
            return redirect(url_for("index"))

    return render_template("add.html", error=error)


@app.route("/delete/<int:formation_id>", methods=["POST"])
def delete_formation(formation_id):
    init_db()
    conn = get_db()
    conn.execute("DELETE FROM formations WHERE id = ?", (formation_id,))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))


@app.route("/api/formations")
def api_formations():
    init_db()
    conn = get_db()
    rows = conn.execute("SELECT * FROM formations").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


@app.route("/health")
def health():
    return {"status": "ok", "service": "formation-app"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
