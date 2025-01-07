CREATE TABLE users (
    user_id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    aadhar_card_number VARCHAR2(12) UNIQUE NOT NULL,
    dob DATE,
    address VARCHAR2(100),
    status VARCHAR2(20) DEFAULT 'Active', 
    is_verified CHAR(1) DEFAULT 'N' 
);


CREATE TABLE admins (
    admin_id NUMBER PRIMARY KEY,
    username VARCHAR2(100) UNIQUE NOT NULL,
    password VARCHAR2(100),
    role VARCHAR2(50), 
    status VARCHAR2(20) DEFAULT 'Active'
);



CREATE TABLE elections (
    election_id NUMBER PRIMARY KEY,
    title VARCHAR2(100),
    start_date DATE,
    end_date DATE,
    election_status VARCHAR2(20),
    admin_id NUMBER,
    FOREIGN KEY (admin_id) REFERENCES admins(admin_id)
);



CREATE TABLE candidates (
    candidate_id NUMBER PRIMARY KEY,
    election_id NUMBER,
    name VARCHAR2(100),
    party_name VARCHAR2(100),
    election_status VARCHAR2(20) DEFAULT 'Active',
    FOREIGN KEY (election_id) REFERENCES elections(election_id)
);

CREATE TABLE votes (
    vote_id NUMBER PRIMARY KEY,
    user_id NUMBER,
    election_id NUMBER,
    candidate_id NUMBER,
    vote_date DATE DEFAULT SYSDATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (election_id) REFERENCES elections(election_id),
    FOREIGN KEY (candidate_id) REFERENCES candidates(candidate_id)
);


CREATE TABLE results (
    result_id NUMBER PRIMARY KEY,
    election_id NUMBER,
    candidate_id NUMBER,
    total_votes NUMBER DEFAULT 0,
    result_status VARCHAR2(20) DEFAULT 'Pending', -- Pending, Declared
    FOREIGN KEY (election_id) REFERENCES elections(election_id),
    FOREIGN KEY (candidate_id) REFERENCES candidates(candidate_id)
);





INSERT INTO users (
    user_id, 
    name, 
    aadhar_card_number, 
    dob, 
    address, 
    status, 
    is_verified
)
VALUES (
    1, 
    'John Doe', 
    '123456789012', 
    TO_DATE('1990-01-01', 'YYYY-MM-DD'), 
    '123 Main St, City, Country', 
    'Active',                      
    'N'   
    );


INSERT INTO admins (admin_id, username, password, role,status)
VALUES (2, 'admin1', 'adminpass123', 'Election Manager','Active');


INSERT INTO elections (election_id, title, start_date, end_date, admin_id)
VALUES (1, '2025 General Election', TO_DATE('2025-04-01', 'YYYY-MM-DD'), TO_DATE('2025-04-10', 'YYYY-MM-DD'), 1);


INSERT INTO candidates (candidate_id, election_id, name, party_name)
VALUES (1, 1, 'Jane Smith', 'Progressive Party');

EXEC vote(p_vote_id => :vote_id, p_user_id => 1, p_election_id => 1, p_candidate_id => 1);


CREATE OR REPLACE PROCEDURE register_user (
    p_user_id OUT NUMBER, 
    p_name IN VARCHAR2,
    p_aadhar IN VARCHAR2,
    p_dob IN DATE,
    p_email IN VARCHAR2,
) 

AS
    new_user_id NUMBER;  
BEGIN

    SELECT NVL(MAX(user_id), 0) + 1 INTO new_user_id FROM users;


    INSERT INTO users (user_id, name, aadhar_card_number, dob, email, password)
    VALUES (new_user_id, p_name, p_aadhar, p_dob, p_email, p_password);

    p_user_id := new_user_id;

    COMMIT;
END;

select * from admins;
select * from users

CREATE OR REPLACE PROCEDURE create_election (
    p_election_id OUT NUMBER,
    p_title IN VARCHAR2,
    p_start_date IN DATE,
    p_end_date IN DATE,
    p_admin_id IN NUMBER
) AS
BEGIN

    INSERT INTO elections (title, start_date, end_date, admin_id)
    VALUES (p_title, p_start_date, p_end_date, p_admin_id)
    RETURNING election_id INTO p_election_id;  
    COMMIT;
END;
/


CREATE OR REPLACE PROCEDURE vote (
    p_vote_id OUT NUMBER,
    p_user_id IN NUMBER,
    p_election_id IN NUMBER,
    p_candidate_id IN NUMBER
) AS
BEGIN

    INSERT INTO votes (user_id, election_id, candidate_id)
    VALUES (p_user_id, p_election_id, p_candidate_id)
    RETURNING vote_id INTO p_vote_id;  
    COMMIT;
END;
/

CREATE OR REPLACE TRIGGER prevent_multiple_votes
BEFORE INSERT ON votes
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM votes
    WHERE user_id = :NEW.user_id
      AND election_id = :NEW.election_id;
    
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'User has already voted in this election');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER update_election_status
BEFORE INSERT OR UPDATE ON elections
FOR EACH ROW
BEGIN
    IF :NEW.start_date > SYSDATE THEN
        :NEW.election_status := 'Not Started';
    ELSIF :NEW.end_date < SYSDATE THEN
        :NEW.election_status := 'Completed';
    ELSE
        :NEW.election_status := 'Ongoing';
    END IF;
END;

/

DECLARE
    CURSOR active_elections_cursor IS
        SELECT election_id, title
        FROM elections
        WHERE election_status = 'Ongoing';
BEGIN
    FOR election IN active_elections_cursor LOOP
        DBMS_OUTPUT.PUT_LINE('Election: ' || election.title || ' (ID: ' || election.election_id || ')');
    END LOOP;
END;

/

CREATE OR REPLACE PROCEDURE calculate_results (
    p_election_id IN NUMBER
) AS
BEGIN

    DELETE FROM results WHERE election_id = p_election_id;
    

    FOR rec IN (SELECT candidate_id FROM candidates WHERE election_id = p_election_id) LOOP
        INSERT INTO results (election_id, candidate_id, total_votes)
        VALUES (p_election_id, rec.candidate_id, 
            (SELECT COUNT(*) FROM votes WHERE election_id = p_election_id AND candidate_id = rec.candidate_id));
    END LOOP;
    UPDATE results 
    SET result_status = 'Declared' 
    WHERE election_id = p_election_id;
    
    COMMIT;
END;
/


CREATE OR REPLACE PROCEDURE display_results (
    p_election_id IN NUMBER
) AS
BEGIN

    DECLARE
        v_election_title VARCHAR2(100);
    BEGIN
        SELECT title INTO v_election_title 
        FROM elections 
        WHERE election_id = p_election_id;
        
        DBMS_OUTPUT.PUT_LINE('Election: ' || v_election_title);
    END;


    FOR rec IN (SELECT c.name, c.party_name, r.total_votes
                FROM candidates c
                JOIN results r ON c.candidate_id = r.candidate_id
                WHERE r.election_id = p_election_id
                AND r.result_status = 'Declared') LOOP
        DBMS_OUTPUT.PUT_LINE('Candidate: ' || rec.name || ', Party: ' || rec.party_name || ', Total Votes: ' || rec.total_votes);
    END LOOP;
END;
/


EXEC calculate_results(p_election_id => 1);



CREATE SEQUENCE results_seq START WITH 1;  

CREATE OR REPLACE PROCEDURE calculate_results (
    p_election_id IN NUMBER
) AS
BEGIN
    DELETE FROM results WHERE election_id = p_election_id;
    
    FOR rec IN (SELECT candidate_id FROM candidates WHERE election_id = p_election_id) LOOP
        INSERT INTO results (result_id, election_id, candidate_id, total_votes)
        VALUES (results_seq.NEXTVAL, p_election_id, rec.candidate_id, 
            (SELECT COUNT(*) FROM votes WHERE election_id = p_election_id AND candidate_id = rec.candidate_id));
    END LOOP;
    
    UPDATE results 
    SET result_status = 'Declared' 
    WHERE election_id = p_election_id;
    
    COMMIT;
END;
/








EXEC display_results(p_election_id => 1);

select * from results;



