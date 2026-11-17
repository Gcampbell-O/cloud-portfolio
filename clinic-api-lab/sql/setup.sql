-- Run in the Azure portal Query editor, signed in as the server's Entra admin.
CREATE TABLE dbo.Clinics (
    Id       INT PRIMARY KEY,
    Name     NVARCHAR(100) NOT NULL,
    City     NVARCHAR(50)  NOT NULL,
    Services NVARCHAR(200) NOT NULL
);

-- Clinic 5 exists only in the database, which proves the app reads from SQL.
INSERT INTO dbo.Clinics (Id, Name, City, Services) VALUES
 (1, 'Sample Community Clinic',     'Omaha',        'Primary care, vaccinations'),
 (2, 'Sample Family Health Center', 'Lincoln',      'Family medicine, WIC'),
 (3, 'Sample Rural Health Clinic',  'Grand Island', 'Primary care, behavioral health'),
 (4, 'Sample Public Health Office', 'Scottsbluff',  'Immunizations, screenings'),
 (5, 'Sample Mid-Plains Clinic',    'North Platte', 'Primary care, dental');

-- Database user for the web app's system-assigned managed identity, read-only.
CREATE USER [<web-app-name>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<web-app-name>];
