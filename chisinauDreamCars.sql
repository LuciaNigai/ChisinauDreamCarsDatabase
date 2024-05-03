-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: May 03, 2024 at 06:14 PM
-- Server version: 8.0.30
-- PHP Version: 7.2.34

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
DELIMITER $$
--
-- Procedures
--
CREATE PROCEDURE `addNewMakeModel` (IN `p_car_make` VARCHAR(50), IN `p_car_model` VARCHAR(50))   BEGIN
   DECLARE v_make_id INT;
   DECLARE v_model_id INT;

   -- Check if the make already exists
   SELECT make_id INTO v_make_id FROM car_make WHERE make = p_car_make;

   -- Check if the model already exists
   SELECT model_id INTO v_model_id FROM car_make_models WHERE model = p_car_model;

   -- If either make or model already exists, raise an error message
   IF v_make_id IS NOT NULL OR v_model_id IS NOT NULL THEN
      SIGNAL SQLSTATE '45000'
         SET MESSAGE_TEXT = 'Make or model already exists. Cannot insert duplicate make or model.';
   ELSE
      -- If make doesn't exist, insert it
      IF v_make_id IS NULL THEN
         INSERT INTO car_make(make) VALUES (p_car_make);
         SET v_make_id = LAST_INSERT_ID();
      END IF;

      -- If model doesn't exist, insert it
      IF v_model_id IS NULL THEN
         INSERT INTO car_make_models(make_id, model) VALUES (v_make_id, p_car_model);
      END IF;
   END IF;
END$$

CREATE PROCEDURE `addNewModel` (IN `p_car_make` VARCHAR(50), IN `p_car_model` VARCHAR(50))   BEGIN
DECLARE v_make_id INT;
DECLARE v_model_id INT;

SELECT make_id into v_make_id FROM car_make WHERE make=p_car_make;

SELECT model_id INTO v_model_id FROM car_make_models WHERE model=p_car_model;

if v_make_id IS NULL then
SIGNAL SQLSTATE '45000'
         SET MESSAGE_TEXT = 'Make does not exist. Cannot insert model of a non existent make.';
else
 IF v_model_id IS NOT NULL THEN
      SIGNAL SQLSTATE '45000'
         SET MESSAGE_TEXT = 'Model already exists. Cannot insert duplicate make or model.';
         else
         INSERT INTO car_make_models(make_id, model)
         VALUES(v_make_id, p_car_model);
         END if;
END if;

END$$

CREATE PROCEDURE `addNewPhoneForUser` (IN `p_user_email` VARCHAR(50), IN `p_new_phone` VARCHAR(50))   BEGIN
    UPDATE user
    SET user.phone = CONCAT(user.phone, ',', p_new_phone)
    WHERE user.email = p_user_email;
END$$

CREATE PROCEDURE `cancelRent` (IN `p_car_plate` VARCHAR(7), IN `p_rent_start` DATETIME, IN `p_rent_end` DATETIME)   BEGIN

SET @userId = (SELECT user_id FROM rented_car 
     JOIN car USING(car_id) 
     WHERE car.car_plate = p_car_plate 
     AND rented_car.rent_start_date_time = p_rent_start AND rented_car.rent_end_date_time = p_rent_end);
  -- updating the user finances data 
  UPDATE user_finances
  JOIN rented_car USING (user_id)
  SET user_finances.total_cashback = user_finances.total_cashback - 
    (SELECT rented_car_cost.rented_car_cashback 
     FROM rented_car_cost 
     JOIN rented_car USING (rented_car_id)
     JOIN car USING (car_id)
     WHERE car.car_plate = p_car_plate AND rented_car.rent_start_date_time = p_rent_start 
     AND rented_car.rent_end_date_time = p_rent_end), 
  user_finances.total_spent = user_finances.total_spent - 
    (SELECT rented_car_cost.rented_car_full_cost 
     FROM rented_car_cost 
     JOIN rented_car USING (rented_car_id)
     JOIN car USING (car_id)
     WHERE car.car_plate = p_car_plate AND rented_car.rent_start_date_time = p_rent_start 
     AND rented_car.rent_end_date_time = p_rent_end)
  WHERE user_finances.user_id = 
    (SELECT user_id FROM rented_car 
     JOIN car USING(car_id) 
     WHERE car.car_plate = p_car_plate 
     AND rented_car.rent_start_date_time = p_rent_start AND rented_car.rent_end_date_time = p_rent_end);
     
# delete the user if the total spent and cashback are empty 
if EXISTS (SELECT user_id FROM user_finances WHERE user_id = @userId AND total_cashback=0 AND total_spent=0) 
then
DELETE FROM user_finances WHERE user_id = @userId;
END if;
  -- delete the car from rented cars
  DELETE FROM rented_car 
  WHERE rented_car.car_id =
    (SELECT car.car_id 
     FROM car 
     WHERE car.car_plate = p_car_plate) 
  AND rented_car.rent_start_date_time = p_rent_start AND rented_car.rent_end_date_time = p_rent_end;

END$$

CREATE  PROCEDURE `changeUserEmail` (IN `p_old_email` VARCHAR(50), IN `p_new_email` VARCHAR(50))   BEGIN

UPDATE user
SET user.email=p_new_email
WHERE user.email=p_old_email;

END$$

CREATE  PROCEDURE `changeUserFirstName` (IN `p_user_email` VARCHAR(50), IN `p_user_first_name` VARCHAR(50))   BEGIN

UPDATE user
SET user.first_name=p_user_first_name
WHERE user.email=p_user_email;

END$$

CREATE PROCEDURE `changeUserLastName` (IN `p_user_email` VARCHAR(50), IN `p_user_last_name` VARCHAR(50))   BEGIN

UPDATE user
SET user.last_name=p_user_last_name
WHERE user.email=p_user_email;

END$$

CREATE PROCEDURE `changeUserPassword` (IN `p_email` VARCHAR(50), IN `p_old_password` VARCHAR(150), IN `p_new_password` VARCHAR(150))   BEGIN

UPDATE user 
SET user.password=p_new_password
WHERE user.email=p_email AND user.password=p_old_password;

END$$

CREATE  PROCEDURE `changeUserPhoneNumber` (IN `p_email` VARCHAR(50), IN `p_phone` VARCHAR(50))   BEGIN

UPDATE user 
SET user.phone=p_phone
WHERE user.email=p_email;

END$$

CREATE  PROCEDURE `checkActiveReservations` (IN `p_email` VARCHAR(50))   BEGIN

SELECT 
   GROUP_CONCAT(car_images.image_path SEPARATOR ',') AS images,
   car.car_plate, 
   car_make.make, 
   car_make_models.model, 
   car.registration_year,
   car_transmission_type.transmission_type,
   car_engine_fuel.engine_fuel,
   rented_car.rent_start_date_time,
   rented_car.rent_end_date_time,
   rented_car_insurance.insurance_type,
   rented_cars_pickup_place.pickup_place,
   rented_car_status.rented_car_status,
   rented_car_status.rented_car_delivery_state,
   rented_car_cost.rented_car_full_cost,
   rented_car_cost.rented_car_cashback,
   rented_car_cost.penalty_if_cancelled,
   rented_car_cost.reserved_car_deposit,
   rented_car_cost.reserved_car_remaining_cost,
   rented_car_damage.compensatory_damages,
   rented_car_damage.compensatory_damages_paid

FROM car
LEFT JOIN car_make_models ON car.model_id = car_make_models.model_id
LEFT JOIN car_make ON car_make_models.make_id = car_make.make_id
LEFT JOIN car_transmission_type ON car.transmission_type_id = car_transmission_type.transmission_type_id
LEFT JOIN car_engine_fuel ON car.engine_fuel_id = car_engine_fuel.engine_fuel_id
LEFT JOIN car_images ON car.car_id = car_images.car_id
LEFT JOIN rented_car ON car.car_id = rented_car.car_id
LEFT JOIN rented_car_status ON rented_car.rented_car_id = rented_car_status.rented_car_id
LEFT JOIN rented_car_cost ON rented_car.rented_car_id = rented_car_cost.rented_car_id
LEFT JOIN rented_car_damage ON rented_car.rented_car_id = rented_car_damage.rented_car_id
LEFT JOIN rented_cars_pickup_place ON rented_car.car_pickup_place=rented_cars_pickup_place.pickup_place_id
LEFT JOIN rented_car_insurance ON rented_car.car_insurance=rented_car_insurance.insurance_id
LEFT JOIN user ON rented_car.user_id = user.user_id

WHERE user.email = p_email AND rented_car_status.rented_car_status NOT IN ('Completed', 'Canceled', 'Returned before final date')

GROUP BY car.car_plate,
         car_make.make, 
         car_make_models.model, 
         car.registration_year,
         car_transmission_type.transmission_type,
         car_engine_fuel.engine_fuel,
         rented_car.rent_start_date_time,
         rented_car.rent_end_date_time,
         rented_car_insurance.insurance_type,
         rented_cars_pickup_place.pickup_place,
         rented_car_status.rented_car_status,
         rented_car_status.rented_car_delivery_state,
         rented_car_cost.rented_car_full_cost,
         rented_car_cost.rented_car_cashback,
         rented_car_cost.penalty_if_cancelled,
         rented_car_cost.reserved_car_deposit,
         rented_car_cost.reserved_car_remaining_cost,
         rented_car_damage.compensatory_damages,
         rented_car_damage.compensatory_damages_paid;

END$$

CREATE  PROCEDURE `checkReservationsHistory` (IN `p_email` VARCHAR(50))   BEGIN

SELECT 
   GROUP_CONCAT(car_images.image_path SEPARATOR ',') AS images,
   car.car_plate, 
   car_make.make, 
   car_make_models.model, 
   car.registration_year,
   car_transmission_type.transmission_type,
   car_engine_fuel.engine_fuel,
   rented_car.rent_start_date_time,
   rented_car.rent_end_date_time,
   rented_car_insurance.insurance_type,
   rented_cars_pickup_place.pickup_place,
   rented_car_status.rented_car_status,
   rented_car_status.rented_car_delivery_state,
   rented_car_cost.rented_car_full_cost,
   rented_car_cost.rented_car_cashback,
   rented_car_cost.penalty_if_cancelled,
   rented_car_cost.reserved_car_deposit,
   rented_car_cost.reserved_car_remaining_cost,
   rented_car_damage.compensatory_damages,
   rented_car_damage.compensatory_damages_paid

FROM car
LEFT JOIN car_make_models ON car.model_id = car_make_models.model_id
LEFT JOIN car_make ON car_make_models.make_id = car_make.make_id
LEFT JOIN car_transmission_type ON car.transmission_type_id = car_transmission_type.transmission_type_id
LEFT JOIN car_engine_fuel ON car.engine_fuel_id = car_engine_fuel.engine_fuel_id
LEFT JOIN car_images ON car.car_id = car_images.car_id
LEFT JOIN rented_car ON car.car_id = rented_car.car_id
LEFT JOIN rented_car_status ON rented_car.rented_car_id = rented_car_status.rented_car_id
LEFT JOIN rented_car_cost ON rented_car.rented_car_id = rented_car_cost.rented_car_id
LEFT JOIN rented_car_damage ON rented_car.rented_car_id = rented_car_damage.rented_car_id
LEFT JOIN rented_cars_pickup_place ON rented_car.car_pickup_place=rented_cars_pickup_place.pickup_place_id
LEFT JOIN rented_car_insurance ON rented_car.car_insurance=rented_car_insurance.insurance_id
LEFT JOIN user ON rented_car.user_id = user.user_id

WHERE user.email = p_email AND rented_car_status.rented_car_status IN ('Completed', 'Canceled', 'Returned before final date')

GROUP BY car.car_plate,
         car_make.make, 
         car_make_models.model, 
         car.registration_year,
         car_transmission_type.transmission_type,
         car_engine_fuel.engine_fuel,
         rented_car.rent_start_date_time,
         rented_car.rent_end_date_time,
         rented_car_insurance.insurance_type,
         rented_cars_pickup_place.pickup_place,
         rented_car_status.rented_car_status,
         rented_car_status.rented_car_delivery_state,
         rented_car_cost.rented_car_full_cost,
         rented_car_cost.rented_car_cashback,
         rented_car_cost.penalty_if_cancelled,
         rented_car_cost.reserved_car_deposit,
         rented_car_cost.reserved_car_remaining_cost,
         rented_car_damage.compensatory_damages,
         rented_car_damage.compensatory_damages_paid;

END$$

CREATE  PROCEDURE `deleteCar` (IN `p_car_plate` VARCHAR(7))   BEGIN
    DECLARE v_model_id INT;
    DECLARE v_make_id INT;
    DECLARE v_make_id2 INT;
    DECLARE v_car_id INT;

    SELECT model_id INTO v_model_id FROM car WHERE car_plate = p_car_plate;
    SELECT make_id INTO v_make_id FROM car_make_models WHERE model_id = v_model_id LIMIT 1;

    DELETE FROM car 
    WHERE car.car_plate = p_car_plate;

    SELECT car_id INTO v_car_id FROM car WHERE model_id = v_model_id LIMIT 1;

    IF v_car_id IS NULL THEN
        DELETE FROM car_make_models
        WHERE model_id = v_model_id;
    END IF;

    SELECT make_id INTO v_make_id2 FROM car_make_models
    WHERE make_id = v_make_id LIMIT 1;

    IF v_make_id2 IS NULL THEN 
        DELETE FROM car_make
        WHERE make_id = v_make_id;
    END IF;
END$$

CREATE  PROCEDURE `deleteManager` (IN `p_manager_email` VARCHAR(50))   BEGIN                     
DELETE FROM users         
WHERE users.user_role='Manager' AND users.email=p_manager_email;
                          
END$$

CREATE PROCEDURE `deleteManagerORCourier` (IN `p_email` VARCHAR(50))   BEGIN

DELETE user FROM user
LEFT JOIN user_roles ON user.user_role_id=user_roles.user_role_id
WHERE (user_roles.user_role='Manager' OR user_roles.user_role='Courier') AND user.email=p_email;
END$$

CREATE  PROCEDURE `getAllUsers` ()   BEGIN
    SELECT user_roles.user_role, user.first_name, user.last_name, user.email, user.phone
    FROM user_roles
    RIGHT JOIN user ON user.user_role_id = user_roles.user_role_id
    WHERE user_roles.user_role="Guest" OR user_roles.user_role="User"
    ORDER BY user_roles.user_role_id;
END$$

CREATE  PROCEDURE `getBodyTypes` ()   BEGIN

SELECT car_body_type.body_type 
FROM car_body_type;

END$$

CREATE  PROCEDURE `getCar` (IN `p_car_plate` CHAR(7))   BEGIN 

SELECT car.car_plate, 
car_make.make, 
car_make_models.model, 
car.registration_year,
car_transmission_type.transmission_type,
car_engine_fuel.engine_fuel,
car.engine_capacity,
car_body_type.body_type,
car.doors_number,
car.passengers_number,
car_description.description_english,
car_description.description_romanian,
car_rent_cost.rent_days_price_1_2,
car_rent_cost.rent_days_price_3_7,
car_rent_cost.rent_days_price_8_20,
car_rent_cost.rent_days_price_21_45,
car_rent_cost.rent_days_price_46,
car.rent_status,
GROUP_CONCAT(car_images.image_path SEPARATOR ',') AS images 
FROM car
LEFT JOIN car_make_models ON car.model_id=car_make_models.model_id
LEFT JOIN car_make ON car_make_models.make_id=car_make.make_id
LEFT JOIN car_transmission_type ON car.transmission_type_id=car_transmission_type.transmission_type_id
LEFT JOIN car_engine_fuel ON car.engine_fuel_id=car_engine_fuel.engine_fuel_id
LEFT JOIN car_body_type ON car.body_type_id=car_body_type.body_type_id
LEFT JOIN car_description ON car.car_id=car_description.car_id
LEFT JOIN car_rent_cost ON car.car_id=car_rent_cost.car_id
LEFT JOIN car_images ON car.car_id=car_images.car_id
WHERE car.car_plate=p_car_plate
GROUP BY car.car_id;

END$$

CREATE  PROCEDURE `getCarImages` (IN `p_car_plate` VARCHAR(50))   BEGIN

SELECT GROUP_CONCAT(car_images.image_path) images
FROM car_images
RIGHT JOIN car ON car_images.car_id=car.car_id
WHERE car.car_plate=p_car_plate;

END$$

CREATE  PROCEDURE `GetCarInformation` ()   BEGIN

SELECT car.car_plate, 
car_make.make, 
car_make_models.model, 
car.registration_year,
car_transmission_type.transmission_type,
car_engine_fuel.engine_fuel,
car.engine_capacity,
car_body_type.body_type,
car.doors_number,
car.passengers_number,
car_description.description_english,
car_description.description_romanian,
car_rent_cost.rent_days_price_1_2,
car_rent_cost.rent_days_price_3_7,
car_rent_cost.rent_days_price_8_20,
car_rent_cost.rent_days_price_21_45,
car_rent_cost.rent_days_price_46,
car.rent_status,
GROUP_CONCAT(car_images.image_path SEPARATOR ',') AS images 
FROM car
LEFT JOIN car_make_models ON car.model_id=car_make_models.model_id
LEFT JOIN car_make ON car_make_models.make_id=car_make.make_id
LEFT JOIN car_transmission_type ON car.transmission_type_id=car_transmission_type.transmission_type_id
LEFT JOIN car_engine_fuel ON car.engine_fuel_id=car_engine_fuel.engine_fuel_id
LEFT JOIN car_body_type ON car.body_type_id=car_body_type.body_type_id
LEFT JOIN car_description ON car.car_id=car_description.car_id
LEFT JOIN car_rent_cost ON car.car_id=car_rent_cost.car_id
LEFT JOIN car_images ON car.car_id=car_images.car_id
GROUP BY car.car_id;
END$$

CREATE  PROCEDURE `getCarsData` ()   BEGIN
    START TRANSACTION;

    SELECT car_make.make, GROUP_CONCAT(car_make_models.model) AS models
    FROM car_make
    LEFT JOIN car_make_models ON car_make.make = car_make_models.make
    GROUP BY car_make.make;

    SELECT * FROM car_transmission;
    SELECT * FROM car_engine_fuel;
    SELECT * FROM car_body_type;
    SELECT * FROM car_doors;
    SELECT * FROM car_passengers_number;

    COMMIT;
END$$

CREATE  PROCEDURE `getDoorsNumber` ()   BEGIN 

SELECT *  FROM car_doors;

END$$

CREATE  PROCEDURE `getEngineFuels` ()   BEGIN 

SELECT *  FROM car_engine_fuel;

END$$

CREATE PROCEDURE `getEngineFuelTypes` ()   BEGIN 

SELECT car_engine_fuel.engine_fuel
FROM car_engine_fuel;

END$$

CREATE  PROCEDURE `getMakeModels` ()   BEGIN

SELECT car_make.make, GROUP_CONCAT(car_make_models.model) AS models FROM car_make
left JOIN 
car_make_models ON car_make.make_id=car_make_models.make_id
GROUP BY make;

END$$

CREATE  PROCEDURE `getMakes` ()   BEGIN 

SELECT car_make.make FROM car_make;

END$$

CREATE  PROCEDURE `GetManagersAndCouriers` ()   BEGIN
SELECT user_roles.user_role, user.first_name, user.last_name, user.email, user.phone
FROM user
LEFT JOIN user_roles USING(user_role_id)
WHERE user_roles.user_role IN('Manager','Courier')
ORDER BY user_roles.user_role;

END$$

CREATE PROCEDURE `getPassengersNumber` ()   BEGIN 

SELECT *  FROM car_passengers_number;

END$$

CREATE  PROCEDURE `getRentedCarDataManager` ()   BEGIN

SELECT user.first_name, user.last_name, user.email, 
user.phone,
user_finances.total_spent, 
user_finances.total_cashback,
user_finances.debt,
car.car_plate,
rented_car.rent_start_date_time,
rented_car.rent_end_date_time,
rented_car_insurance.insurance_type,
rented_cars_pickup_place.pickup_place,
rented_car_cost.rented_car_full_cost,
rented_car_cost.rented_car_cashback

FROM user 
LEFT JOIN user_finances USING(user_id)
RIGHT JOIN rented_car USING (user_id)
LEFT JOIN car USING(car_id)
LEFT JOIN rented_car_insurance ON rented_car.car_insurance=rented_car_insurance.insurance_id
LEFT JOIN rented_cars_pickup_place ON rented_car.car_pickup_place=rented_cars_pickup_place.pickup_place_id
LEFT JOIN rented_car_cost USING(rented_car_id);

END$$

CREATE PROCEDURE `getRentedCardDataManager` ()   BEGIN

SELECT user.first_name, user.last_name, user.email, 
user.phone,
user_finances.total_spent, 
user_finances.total_cashback,
user_finances.debt,
car.car_plate,
rented_car.rent_start_date_time,
rented_car.rent_end_date_time,
rented_car_insurance.insurance_type,
rented_cars_pickup_place.pickup_place,
rented_car_cost.rented_car_full_cost,
rented_car_cost.rented_car_cashback

FROM user 
LEFT JOIN user_finances USING(user_id)
RIGHT JOIN rented_car USING (user_id)
LEFT JOIN car USING(car_id)
LEFT JOIN rented_car_insurance ON rented_car.car_insurance=rented_car_insurance.insurance_id
LEFT JOIN rented_cars_pickup_place ON rented_car.car_pickup_place=rented_cars_pickup_place.pickup_place_id
LEFT JOIN rented_car_cost USING(rented_car_id);

END$$

CREATE PROCEDURE `getTransmissions` ()   BEGIN 

SELECT *  FROM car_transmission;

END$$

CREATE PROCEDURE `getTransmissionTypes` ()   BEGIN 

SELECT car_transmission_type.transmission_type  FROM car_transmission_type;

END$$

CREATE PROCEDURE `getUserAccountData` (IN `p_email` VARCHAR(50))   BEGIN

SELECT
GROUP_CONCAT(car_images.image_path SEPARATOR ',') AS images,
car.car_plate,
car_make.make,
car_make_models.model,
car.registration_year,
car.engine_capacity,
car_engine_fuel.engine_fuel, 
car_transmission_type.transmission_type,
car_body_type.body_type,
car.doors_number,
car.passengers_number,
rented_car.rent_start_date_time,
rented_car.rent_end_date_time,
rented_car_insurance.insurance_type,
rented_cars_pickup_place.pickup_place,
rented_car_cost.rented_car_full_cost,
rented_car_cost.rented_car_cashback

FROM user 
LEFT JOIN rented_car USING (user_id)
LEFT JOIN car USING(car_id)
LEFT JOIN car_images USING(car_id)
LEFT JOIN car_make_models USING (model_id)
LEFT JOIN car_make USING(make_id)
LEFT JOIN car_engine_fuel USING(engine_fuel_id)
LEFT JOIN car_transmission_type USING(transmission_type_id)
LEFT JOIN car_body_type USING(body_type_id)
LEFT JOIN rented_car_insurance ON rented_car.car_insurance=rented_car_insurance.insurance_id
LEFT JOIN rented_cars_pickup_place ON rented_car.car_pickup_place=rented_cars_pickup_place.pickup_place_id
LEFT JOIN rented_car_cost USING(rented_car_id)
WHERE user.email=p_email
GROUP BY car.car_plate;


END$$

CREATE PROCEDURE `getUserData` (IN `p_email` VARCHAR(50))   BEGIN

SELECT user.first_name, user.last_name, user.email, 
user.phone,
user_finances.total_spent, 
user_finances.total_cashback,
user_finances.debt
FROM user 
LEFT JOIN user_finances USING(user_id)
WHERE user.email=p_email;

END$$

CREATE  PROCEDURE `getUserRentedCars` (IN `p_email` VARCHAR(50))   BEGIN

SELECT
GROUP_CONCAT(car_images.image_path SEPARATOR ',') AS images,
car.car_plate,
car_make.make,
car_make_models.model,
car.registration_year,
car.engine_capacity,
car_engine_fuel.engine_fuel, 
car_transmission_type.transmission_type,
car_body_type.body_type,
car.doors_number,
car.passengers_number,
rented_car.rent_start_date_time,
rented_car.rent_end_date_time,
rented_car_insurance.insurance_type,
rented_cars_pickup_place.pickup_place,
rented_car_cost.rented_car_full_cost,
rented_car_cost.rented_car_cashback

FROM user 
LEFT JOIN rented_car USING (user_id)
LEFT JOIN car USING(car_id)
LEFT JOIN car_images USING(car_id)
LEFT JOIN car_make_models USING (model_id)
LEFT JOIN car_make USING(make_id)
LEFT JOIN car_engine_fuel USING(engine_fuel_id)
LEFT JOIN car_transmission_type USING(transmission_type_id)
LEFT JOIN car_body_type USING(body_type_id)
LEFT JOIN rented_car_insurance ON rented_car.car_insurance=rented_car_insurance.insurance_id
LEFT JOIN rented_cars_pickup_place ON rented_car.car_pickup_place=rented_cars_pickup_place.pickup_place_id
LEFT JOIN rented_car_cost USING(rented_car_id)
WHERE user.email=p_email
GROUP BY car.car_plate,
car_make.make,
car_make_models.model,
car.registration_year,
car.engine_capacity,
car_engine_fuel.engine_fuel, 
car_transmission_type.transmission_type,
car_body_type.body_type,
car.doors_number,
car.passengers_number,
rented_car.rent_start_date_time,
rented_car.rent_end_date_time,
rented_car_insurance.insurance_type,
rented_cars_pickup_place.pickup_place,
rented_car_cost.rented_car_full_cost,
rented_car_cost.rented_car_cashback;


END$$

CREATE  PROCEDURE `getUserRole` (IN `p_email` VARCHAR(100))   BEGIN
SELECT user_roles.user_role
FROM user_roles
RIGHT JOIN user ON user_roles.user_role_id=user.user_role_id
WHERE user.email=p_email;

END$$

CREATE  PROCEDURE `InsertCarAndImages` (IN `p_car_plate` CHAR(7), IN `p_car_make` VARCHAR(255), IN `p_car_model` VARCHAR(255), IN `p_registration_year` INT, IN `p_engine_capacity` VARCHAR(10), IN `p_engine_fuel` VARCHAR(255), IN `p_transmission_type` VARCHAR(255), IN `p_body_type` VARCHAR(255), IN `p_doors` INT, IN `p_passengers_number` INT, IN `p_rent_days_price_1_2` INT, IN `p_rent_days_price_3_7` INT, IN `p_rent_days_price_8_20` INT, IN `p_rent_days_price_21_45` INT, IN `p_rent_days_price_46` INT, IN `p_description_eng` VARCHAR(1500), IN `p_description_rom` VARCHAR(1500), IN `p_image_paths_string` VARCHAR(500))   BEGIN
    DECLARE v_make_id  INT;
    DECLARE v_model_id INT;

    -- Check if the make already exists
    SELECT make_id INTO v_make_id FROM car_make WHERE make = p_car_make;

    -- Check if the model already exists
    SELECT model_id INTO v_model_id FROM car_make_models WHERE model = p_car_model;

    -- If make doesn't exist, insert it
    IF v_make_id IS NULL THEN
        INSERT INTO car_make(make) VALUES (p_car_make);
        SET v_make_id = LAST_INSERT_ID();
    END IF;

    -- If model doesn't exist, insert it
    IF v_model_id IS NULL THEN
        INSERT INTO car_make_models(make_id, model) VALUES (v_make_id, p_car_model);
        SET v_model_id = LAST_INSERT_ID();
    ELSE
        -- Check if the existing model is related to the specified make
        IF (SELECT make_id FROM car_make_models WHERE model = p_car_model) != v_make_id THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Model already exists and is related to another make.';
        END IF;
    END IF;

    -- Insert into car table
    INSERT INTO car (car_plate, model_id, registration_year, engine_capacity, engine_fuel_id, transmission_type_id, body_type_id, doors_number, passengers_number)
    VALUES (
        p_car_plate,
        v_model_id,
        p_registration_year,
        p_engine_capacity,
        (SELECT engine_fuel_id FROM car_engine_fuel WHERE engine_fuel = p_engine_fuel),
        (SELECT transmission_type_id FROM car_transmission_type WHERE transmission_type = p_transmission_type),
        (SELECT body_type_id FROM car_body_type WHERE body_type = p_body_type),
        p_doors,
        p_passengers_number
    );

    SET @last_id = LAST_INSERT_ID();

    -- Insert into car_rent_cost table
    INSERT INTO car_rent_cost(car_id, rent_days_price_1_2, rent_days_price_3_7, rent_days_price_8_20, rent_days_price_21_45, rent_days_price_46)
    VALUES (@last_id, p_rent_days_price_1_2, p_rent_days_price_3_7, p_rent_days_price_8_20, p_rent_days_price_21_45, p_rent_days_price_46);

    -- Insert into car_description table
    INSERT INTO car_description (car_id, description_english, description_romanian)
    VALUES (@last_id, p_description_eng, p_description_rom);

    SET @image_paths = p_image_paths_string;

    -- Split the image paths using the specified delimiter
    REPEAT
        SET @delimiter_position = LOCATE(',', @image_paths);
        IF @delimiter_position > 0 THEN
            SET @image_path = SUBSTRING(@image_paths, 1, @delimiter_position - 1);
            SET @image_paths = SUBSTRING(@image_paths, @delimiter_position + 1);
        ELSE
            SET @image_path = @image_paths;
            SET @image_paths = '';
        END IF;

        -- Insert into car_images table
        INSERT INTO car_images (car_id, image_path)
        VALUES (@last_id, @image_path);
    UNTIL LENGTH(@image_paths) = 0 END REPEAT;

    COMMIT;
END$$

CREATE  PROCEDURE `InsertOrUpdateCarAndImages` (IN `p_car_plate` CHAR(7), IN `p_car_make` VARCHAR(255), IN `p_car_model` VARCHAR(255), IN `p_registration_year` INT, IN `p_engine_capacity` VARCHAR(10), IN `p_engine_fuel` VARCHAR(255), IN `p_transmission_type` VARCHAR(255), IN `p_body_type` VARCHAR(255), IN `p_doors` INT, IN `p_passengers_number` INT, IN `p_rent_days_price_1_2` INT, IN `p_rent_days_price_3_7` INT, IN `p_rent_days_price_8_20` INT, IN `p_rent_days_price_21_45` INT, IN `p_rent_days_price_46` INT, IN `p_description` VARCHAR(1500), IN `p_image_paths_string` VARCHAR(500))   BEGIN

    DECLARE make_id VARCHAR(255);
    DECLARE model_id VARCHAR(255);

    START TRANSACTION;

    -- Check if make exists, insert if not
    SELECT make INTO make_id FROM car_make WHERE make = p_car_make;
    IF make_id IS NULL THEN
        INSERT INTO car_make (make) VALUES (p_car_make);
        SET make_id = p_car_make;
    END IF;

    -- Check if model exists, insert if not
    SELECT model INTO model_id FROM car_make_models WHERE model = p_car_model;
    IF model_id IS NULL THEN
        INSERT INTO car_make_models (make, model) VALUES (p_car_make, p_car_model);
        SET model_id = p_car_model;
    END IF;

    -- Insert or update into cars
    INSERT INTO cars (
        car_plate, car_make, car_make_model, registration_year, engine_capacity,
        engine_fuel, transmission_type, body_type, doors, passengers_number,
        rent_days_price_1_2, rent_days_price_3_7, rent_days_price_8_20, rent_days_price_21_45,
        rent_days_price_46, car_description, rent_status
    )
    VALUES (
        p_car_plate,
        (SELECT make FROM car_make WHERE make = p_car_make),
        (SELECT model FROM car_make_models WHERE model = p_car_model), 
        p_registration_year, p_engine_capacity,
        (SELECT engine_fuel FROM car_engine_fuel WHERE engine_fuel = p_engine_fuel),
        (SELECT transmission_type FROM car_transmission WHERE transmission_type = p_transmission_type),
        (SELECT body_type FROM car_body_type WHERE body_type = p_body_type),
        (SELECT doors_number FROM car_doors WHERE doors_number = p_doors),
        (SELECT passengers_number FROM car_passengers_number WHERE passengers_number = p_passengers_number),
        p_rent_days_price_1_2, p_rent_days_price_3_7, p_rent_days_price_8_20, p_rent_days_price_21_45,
        p_rent_days_price_46, p_description, DEFAULT
    )
    ON DUPLICATE KEY UPDATE
        car_make = VALUES(car_make),
        car_make_model = VALUES(car_make_model),
        registration_year = VALUES(registration_year),
        engine_capacity = VALUES(engine_capacity),
        engine_fuel = VALUES(engine_fuel),
        transmission_type = VALUES(transmission_type),
        body_type = VALUES(body_type),
        doors = VALUES(doors),
        passengers_number = VALUES(passengers_number),
        rent_days_price_1_2 = VALUES(rent_days_price_1_2),
        rent_days_price_3_7 = VALUES(rent_days_price_3_7),
        rent_days_price_8_20 = VALUES(rent_days_price_8_20),
        rent_days_price_21_45 = VALUES(rent_days_price_21_45),
        rent_days_price_46 = VALUES(rent_days_price_46),
        car_description = VALUES(car_description);

    SET @last_id = LAST_INSERT_ID();
    SET @image_paths = p_image_paths_string;

    -- Delete existing images for the updated car
    DELETE FROM cars_images WHERE car_id = @last_id;

    -- Split the image paths using the specified delimiter
    REPEAT
        SET @delimiter_position = LOCATE(',', @image_paths);
        IF @delimiter_position > 0 THEN
            SET @image_path = SUBSTRING(@image_paths, 1, @delimiter_position - 1);
            SET @image_paths = SUBSTRING(@image_paths, @delimiter_position + 1);
        ELSE
            SET @image_path = @image_paths;
            SET @image_paths = '';
        END IF;

        -- Insert into cars_images
        INSERT INTO cars_images (car_id, image_path) 
        VALUES (@last_id, @image_path);
    UNTIL LENGTH(@image_paths) = 0 END REPEAT;

    COMMIT;
END$$

CREATE PROCEDURE `RentCar` (IN `p_user_first_name` VARCHAR(50), IN `p_user_last_name` VARCHAR(50), IN `p_user_email` VARCHAR(50), IN `p_user_phone` VARCHAR(50), IN `p_car_plate` CHAR(7), IN `p_rent_start` DATETIME, IN `p_rent_end` DATETIME, IN `p_car_insurance` VARCHAR(50), IN `p_car_pickup_place` VARCHAR(50), IN `p_full_cost` INT, IN `p_cashback` INT)   BEGIN 
# if user already exists insert the data about the rented car in rented_cars
    IF EXISTS (SELECT user_id FROM user WHERE email = p_user_email) THEN
        INSERT INTO rented_car (car_id,user_id,rent_start_date_time,rent_end_date_time, car_insurance,car_pickup_place)
        VALUES (
            (SELECT car_id FROM car WHERE car_plate = p_car_plate), 
            (SELECT user_id FROM user WHERE email = p_user_email),
            STR_TO_DATE(p_rent_start, '%Y-%m-%d %H:%i:%s'), 
            STR_TO_DATE(p_rent_end, '%Y-%m-%d %H:%i:%s'), 
            (SELECT insurance_id FROM rented_car_insurance WHERE insurance_type = p_car_insurance),
            (SELECT pickup_place_id FROM rented_cars_pickup_place WHERE pickup_place = p_car_pickup_place)
        );
        SET @rented_car_id = LAST_INSERT_ID();
# inserting the infromation about car cost
        INSERT INTO rented_car_cost (rented_car_id, rented_car_full_cost, rented_car_cashback)
        VALUES (@rented_car_id, p_full_cost, p_cashback);
        
			#inserting or updating the user finances data 
				if EXISTS (SELECT user_finances.user_id FROM user_finances LEFT JOIN user USING(user_id) WHERE user.email=p_user_email) then
					# updating the user finances data 
			        UPDATE user_finances
			        LEFT JOIN user USING(user_id)
			        SET user_finances.total_cashback =user_finances.total_cashback+p_cashback, 
						 user_finances.total_spent=user_finances.total_spent+p_full_cost
					  WHERE user.email=p_user_email;
				else
				INSERT INTO user_finances (user_id,user_finances.total_cashback, user_finances.total_spent)
				VALUES ((SELECT user_id FROM user WHERE email=p_user_email),p_cashback, p_full_cost);
				END if;
	
       
# if user does not exists add user as a guest 
    ELSE
        INSERT INTO user (user_role_id, first_name,last_name, password,email,phone)
        VALUES (
            (SELECT user_role_id FROM user_roles WHERE user_role = 'Guest'), 
            p_user_first_name, 
            p_user_last_name, 
            '1111', 
            p_user_email, 
            p_user_phone
        );
        SET @user_id = LAST_INSERT_ID();
# insert info about the rented car inside rented_cars
        INSERT INTO rented_car (car_id,user_id,rent_start_date_time,rent_end_date_time, car_insurance,car_pickup_place)
        VALUES (
            (SELECT car_id FROM car WHERE car_plate = p_car_plate), 
            @user_id,
            STR_TO_DATE(p_rent_start, '%Y-%m-%d %H:%i:%s'), 
            STR_TO_DATE(p_rent_end, '%Y-%m-%d %H:%i:%s'), 
            (SELECT insurance_id FROM rented_car_insurance WHERE insurance_type = p_car_insurance),
            (SELECT pickup_place_id FROM rented_cars_pickup_place WHERE pickup_place = p_car_pickup_place)
        );
        SET @rented_car_id = LAST_INSERT_ID();
#insert info about the rented car cost into rented_car_cost
        INSERT INTO rented_car_cost (rented_car_id, rented_car_full_cost, rented_car_cashback)
        VALUES (@rented_car_id, p_full_cost, p_cashback);
    END IF;
END$$

CREATE PROCEDURE `UpdateCarAndImages` (IN `old_car_plate` CHAR(7), IN `p_car_plate` CHAR(7), IN `p_car_make` VARCHAR(255), IN `p_car_model` VARCHAR(255), IN `p_registration_year` INT, IN `p_engine_capacity` VARCHAR(10), IN `p_engine_fuel` VARCHAR(255), IN `p_transmission_type` VARCHAR(255), IN `p_body_type` VARCHAR(255), IN `p_doors` INT, IN `p_passengers_number` INT, IN `p_rent_days_price_1_2` INT, IN `p_rent_days_price_3_7` INT, IN `p_rent_days_price_8_20` INT, IN `p_rent_days_price_21_45` INT, IN `p_rent_days_price_46` INT, IN `p_description` VARCHAR(1500), IN `p_image_paths_string` VARCHAR(500))   BEGIN
    DECLARE old_car_id INT;
    DECLARE old_make VARCHAR(255);
    DECLARE old_model VARCHAR(255);

    -- Select old car details
    SELECT c.car_id, c.car_make, c.car_make_model
    INTO old_car_id, old_make, old_model
    FROM cars c
    WHERE c.car_plate = old_car_plate;

    START TRANSACTION;

    -- Check if car_make already exists
    SELECT make INTO @existing_make FROM car_make WHERE make = p_car_make;

    IF @existing_make IS NOT NULL THEN
        -- Make already exists, update cars table with existing value
        UPDATE cars
        SET
            car_plate = p_car_plate,
            car_make = @existing_make,
            car_make_model = p_car_model,
            registration_year = p_registration_year,
            engine_capacity = p_engine_capacity,
            engine_fuel = (SELECT engine_fuel FROM car_engine_fuel WHERE engine_fuel = p_engine_fuel),
            transmission_type = (SELECT transmission_type FROM car_transmission WHERE transmission_type = p_transmission_type),
            body_type = (SELECT body_type FROM car_body_type WHERE body_type = p_body_type),
            doors = (SELECT doors_number FROM car_doors WHERE doors_number = p_doors),
            passengers_number = (SELECT passengers_number FROM car_passengers_number WHERE passengers_number = p_passengers_number),
            rent_days_price_1_2 = p_rent_days_price_1_2,
            rent_days_price_3_7 = p_rent_days_price_3_7,
            rent_days_price_8_20 = p_rent_days_price_8_20,
            rent_days_price_21_45 = p_rent_days_price_21_45,
            rent_days_price_46 = p_rent_days_price_46,
            car_description = p_description
        WHERE car_id = old_car_id;

        -- Delete the old make
        DELETE FROM car_make WHERE make = old_make;
    ELSE
        -- Make doesn't exist, update car_make and cars table
        UPDATE car_make
        SET make = p_car_make WHERE make = old_make;

        -- Update the car model
        UPDATE car_make_models
        SET model = p_car_model WHERE model = old_model AND make = p_car_make;

        -- Update the existing car data
        UPDATE cars
        SET
            car_plate = p_car_plate,
            car_make = p_car_make,
            car_make_model = p_car_model,
            registration_year = p_registration_year,
            engine_capacity = p_engine_capacity,
            engine_fuel = (SELECT engine_fuel FROM car_engine_fuel WHERE engine_fuel = p_engine_fuel),
            transmission_type = (SELECT transmission_type FROM car_transmission WHERE transmission_type = p_transmission_type),
            body_type = (SELECT body_type FROM car_body_type WHERE body_type = p_body_type),
            doors = (SELECT doors_number FROM car_doors WHERE doors_number = p_doors),
            passengers_number = (SELECT passengers_number FROM car_passengers_number WHERE passengers_number = p_passengers_number),
            rent_days_price_1_2 = p_rent_days_price_1_2,
            rent_days_price_3_7 = p_rent_days_price_3_7,
            rent_days_price_8_20 = p_rent_days_price_8_20,
            rent_days_price_21_45 = p_rent_days_price_21_45,
            rent_days_price_46 = p_rent_days_price_46,
            car_description = p_description
        WHERE car_id = old_car_id;
    END IF;

    -- Delete existing images for the updated car
    DELETE FROM cars_images WHERE car_id = old_car_id;

    -- Split the image paths using the specified delimiter
    SET @image_paths = p_image_paths_string;

    REPEAT
        SET @delimiter_position = LOCATE(',', @image_paths);
        IF @delimiter_position > 0 THEN
            SET @image_path = SUBSTRING(@image_paths, 1, @delimiter_position - 1);
            SET @image_paths = SUBSTRING(@image_paths, @delimiter_position + 1);
        ELSE
            SET @image_path = @image_paths;
            SET @image_paths = '';
        END IF;

        -- Insert into cars_images
        INSERT INTO cars_images (car_id, image_path) 
        VALUES (old_car_id, @image_path);
    UNTIL LENGTH(@image_paths) = 0 END REPEAT;

    COMMIT;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `car`
--

CREATE TABLE `car` (
  `car_id` int NOT NULL,
  `car_plate` char(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `model_id` int NOT NULL,
  `registration_year` int NOT NULL,
  `engine_capacity` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `engine_fuel_id` int NOT NULL,
  `transmission_type_id` int NOT NULL,
  `body_type_id` int NOT NULL,
  `doors_number` tinyint NOT NULL,
  `passengers_number` tinyint NOT NULL,
  `rent_status` enum('disponibila','nedisponibila') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'disponibila'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `car`
--

INSERT INTO `car` (`car_id`, `car_plate`, `model_id`, `registration_year`, `engine_capacity`, `engine_fuel_id`, `transmission_type_id`, `body_type_id`, `doors_number`, `passengers_number`, `rent_status`) VALUES
(164, 'ABC 123', 20, 2017, '2.5', 1, 1, 1, 5, 5, 'disponibila'),
(165, 'AAA 322', 20, 2018, '2.6', 1, 3, 1, 4, 4, 'nedisponibila'),
(166, 'FVG 574', 20, 2023, '2.7', 2, 2, 1, 3, 6, 'disponibila'),
(167, 'SDQ 079', 21, 2012, '2.1', 2, 1, 2, 3, 3, 'disponibila');

-- --------------------------------------------------------

--
-- Table structure for table `car_body_type`
--

CREATE TABLE `car_body_type` (
  `body_type_id` int NOT NULL,
  `body_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `car_body_type`
--

INSERT INTO `car_body_type` (`body_type_id`, `body_type`) VALUES
(1, 'Crossover'),
(2, 'Sedan');

-- --------------------------------------------------------

--
-- Table structure for table `car_description`
--

CREATE TABLE `car_description` (
  `description_id` int NOT NULL,
  `car_id` int NOT NULL,
  `description_english` varchar(1500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `description_romanian` varchar(1500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `car_engine_fuel`
--

CREATE TABLE `car_engine_fuel` (
  `engine_fuel_id` int NOT NULL,
  `engine_fuel` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `car_engine_fuel`
--

INSERT INTO `car_engine_fuel` (`engine_fuel_id`, `engine_fuel`) VALUES
(1, 'Benzina'),
(2, 'Diesel');

-- --------------------------------------------------------

--
-- Table structure for table `car_images`
--

CREATE TABLE `car_images` (
  `image_id` int NOT NULL,
  `car_id` int NOT NULL,
  `image_path` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `car_make`
--

CREATE TABLE `car_make` (
  `make_id` int NOT NULL,
  `make` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `car_make`
--

INSERT INTO `car_make` (`make_id`, `make`) VALUES
(2, 'Nissan');

-- --------------------------------------------------------

--
-- Table structure for table `car_make_models`
--

CREATE TABLE `car_make_models` (
  `model_id` int NOT NULL,
  `make_id` int NOT NULL,
  `model` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `car_make_models`
--

INSERT INTO `car_make_models` (`model_id`, `make_id`, `model`) VALUES
(20, 2, 'AAA'),
(21, 2, 'bbb');

-- --------------------------------------------------------

--
-- Table structure for table `car_rent_cost`
--

CREATE TABLE `car_rent_cost` (
  `car_cost_id` int NOT NULL,
  `car_id` int NOT NULL,
  `rent_days_price_1_2` int NOT NULL,
  `rent_days_price_3_7` int NOT NULL,
  `rent_days_price_8_20` int NOT NULL,
  `rent_days_price_21_45` int NOT NULL,
  `rent_days_price_46` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `car_rent_cost`
--

INSERT INTO `car_rent_cost` (`car_cost_id`, `car_id`, `rent_days_price_1_2`, `rent_days_price_3_7`, `rent_days_price_8_20`, `rent_days_price_21_45`, `rent_days_price_46`) VALUES
(24, 165, 12, 23, 34, 34, 22),
(25, 164, 33, 12, 44, 33, 33);

-- --------------------------------------------------------

--
-- Table structure for table `car_transmission_type`
--

CREATE TABLE `car_transmission_type` (
  `transmission_type_id` int NOT NULL,
  `transmission_type` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `car_transmission_type`
--

INSERT INTO `car_transmission_type` (`transmission_type_id`, `transmission_type`) VALUES
(1, 'Automat'),
(2, 'Mecanica'),
(3, 'Robotizata');

-- --------------------------------------------------------

--
-- Table structure for table `rented_car`
--

CREATE TABLE `rented_car` (
  `rented_car_id` int NOT NULL,
  `car_id` int NOT NULL,
  `user_id` int NOT NULL,
  `rent_start_date_time` datetime NOT NULL,
  `rent_end_date_time` datetime NOT NULL,
  `car_insurance` int NOT NULL,
  `car_pickup_place` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `rented_cars_pickup_place`
--

CREATE TABLE `rented_cars_pickup_place` (
  `pickup_place_id` int NOT NULL,
  `pickup_place` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `rented_cars_pickup_place`
--

INSERT INTO `rented_cars_pickup_place` (`pickup_place_id`, `pickup_place`) VALUES
(1, 'Aeroport');

-- --------------------------------------------------------

--
-- Table structure for table `rented_car_cost`
--

CREATE TABLE `rented_car_cost` (
  `rented_car_cost_id` int NOT NULL,
  `rented_car_id` int NOT NULL,
  `rented_car_full_cost` int NOT NULL,
  `rented_car_cashback` int NOT NULL,
  `penalty_if_cancelled` int DEFAULT NULL,
  `reserved_car_deposit` int DEFAULT NULL,
  `reserved_car_remaining_cost` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `rented_car_damage`
--

CREATE TABLE `rented_car_damage` (
  `rented_car_damage_id` int NOT NULL,
  `rented_car_id` int NOT NULL,
  `compensatory_damages` int NOT NULL,
  `compensatory_damages_paid` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `rented_car_insurance`
--

CREATE TABLE `rented_car_insurance` (
  `insurance_id` int NOT NULL,
  `insurance_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `rented_car_insurance`
--

INSERT INTO `rented_car_insurance` (`insurance_id`, `insurance_type`) VALUES
(1, 'Casco'),
(2, 'RCA');

-- --------------------------------------------------------

--
-- Table structure for table `rented_car_status`
--

CREATE TABLE `rented_car_status` (
  `rented_car_status_id` int NOT NULL,
  `rented_car_id` int NOT NULL,
  `rented_car_status` enum('Awaiting deposit','Awaiting final payment','Cancelled','In process','In use','Returned before final date','Completed') NOT NULL DEFAULT 'Awaiting final payment',
  `rented_car_delivery_state` enum('Awaiting Delivery Date','Awaiting courier','Awaiting delivery','Delivered','Cancelled') NOT NULL DEFAULT 'Awaiting Delivery Date'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user`
--

CREATE TABLE `user` (
  `user_id` int NOT NULL,
  `user_role_id` int NOT NULL,
  `first_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `last_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `password` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `phone` varchar(50) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `user`
--

INSERT INTO `user` (`user_id`, `user_role_id`, `first_name`, `last_name`, `password`, `email`, `phone`) VALUES
(1, 5, 'Lucy', 'Baba', 'df3743ryhew984734rhew987483hr87343ghrieriwuwte', 'lucy@gmail.com', '538974589'),
(9, 4, 'bbbb', 'bbbb', '3i3r7i4387grewo78e6rygeuo7w4rwgeus', 'bbbb@gmail.com', '5896321547'),
(10, 3, 'Vlad', 'Ungur', '1111', 'vlad@gmail.com', '11111112'),
(11, 3, 'Vladislove', 'Ungur', '1234567890', 'Vladislove@gmail.com', '067534234');

-- --------------------------------------------------------

--
-- Table structure for table `user_finances`
--

CREATE TABLE `user_finances` (
  `user_finances_id` int NOT NULL,
  `user_id` int NOT NULL,
  `total_cashback` int DEFAULT '0',
  `total_spent` int DEFAULT '0',
  `debt` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_roles`
--

CREATE TABLE `user_roles` (
  `user_role_id` int NOT NULL,
  `user_role` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `user_roles`
--

INSERT INTO `user_roles` (`user_role_id`, `user_role`) VALUES
(1, 'Admin'),
(2, 'Courier'),
(3, 'Guest'),
(4, 'Manager'),
(5, 'User');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `car`
--
ALTER TABLE `car`
  ADD PRIMARY KEY (`car_id`),
  ADD UNIQUE KEY `car_id` (`car_id`),
  ADD UNIQUE KEY `car_plate` (`car_plate`),
  ADD KEY `car_make_model_index` (`model_id`),
  ADD KEY `engine_fuel_index` (`engine_fuel_id`),
  ADD KEY `transmission_type_index` (`transmission_type_id`),
  ADD KEY `body_type_index` (`body_type_id`),
  ADD KEY `doors_index` (`doors_number`),
  ADD KEY `passengers_number_index` (`passengers_number`);

--
-- Indexes for table `car_body_type`
--
ALTER TABLE `car_body_type`
  ADD PRIMARY KEY (`body_type_id`),
  ADD UNIQUE KEY `car_body_type` (`body_type`);

--
-- Indexes for table `car_description`
--
ALTER TABLE `car_description`
  ADD PRIMARY KEY (`description_id`),
  ADD UNIQUE KEY `car_id` (`car_id`);

--
-- Indexes for table `car_engine_fuel`
--
ALTER TABLE `car_engine_fuel`
  ADD PRIMARY KEY (`engine_fuel_id`),
  ADD UNIQUE KEY `engine_fuel` (`engine_fuel`);

--
-- Indexes for table `car_images`
--
ALTER TABLE `car_images`
  ADD PRIMARY KEY (`image_id`),
  ADD UNIQUE KEY `image_id` (`image_id`),
  ADD KEY `car_id` (`car_id`);

--
-- Indexes for table `car_make`
--
ALTER TABLE `car_make`
  ADD PRIMARY KEY (`make_id`),
  ADD UNIQUE KEY `make` (`make`);

--
-- Indexes for table `car_make_models`
--
ALTER TABLE `car_make_models`
  ADD PRIMARY KEY (`model_id`),
  ADD UNIQUE KEY `car_make_model` (`model`),
  ADD KEY `car_make_models_ibfk_1` (`make_id`);

--
-- Indexes for table `car_rent_cost`
--
ALTER TABLE `car_rent_cost`
  ADD PRIMARY KEY (`car_cost_id`),
  ADD UNIQUE KEY `car_id` (`car_id`);

--
-- Indexes for table `car_transmission_type`
--
ALTER TABLE `car_transmission_type`
  ADD PRIMARY KEY (`transmission_type_id`),
  ADD UNIQUE KEY `transmission_type` (`transmission_type`);

--
-- Indexes for table `rented_car`
--
ALTER TABLE `rented_car`
  ADD PRIMARY KEY (`rented_car_id`),
  ADD UNIQUE KEY `rented_car_id` (`rented_car_id`),
  ADD KEY `car_id` (`car_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `car_insurance` (`car_insurance`),
  ADD KEY `car_pickup_place` (`car_pickup_place`);

--
-- Indexes for table `rented_cars_pickup_place`
--
ALTER TABLE `rented_cars_pickup_place`
  ADD PRIMARY KEY (`pickup_place_id`);

--
-- Indexes for table `rented_car_cost`
--
ALTER TABLE `rented_car_cost`
  ADD PRIMARY KEY (`rented_car_cost_id`),
  ADD UNIQUE KEY `rented_car_id` (`rented_car_id`);

--
-- Indexes for table `rented_car_damage`
--
ALTER TABLE `rented_car_damage`
  ADD PRIMARY KEY (`rented_car_damage_id`),
  ADD KEY `rented_car_id` (`rented_car_id`);

--
-- Indexes for table `rented_car_insurance`
--
ALTER TABLE `rented_car_insurance`
  ADD PRIMARY KEY (`insurance_id`);

--
-- Indexes for table `rented_car_status`
--
ALTER TABLE `rented_car_status`
  ADD PRIMARY KEY (`rented_car_status_id`),
  ADD KEY `rented_car_id` (`rented_car_id`);

--
-- Indexes for table `user`
--
ALTER TABLE `user`
  ADD PRIMARY KEY (`user_id`),
  ADD KEY `users_ibfk_1` (`user_role_id`);

--
-- Indexes for table `user_finances`
--
ALTER TABLE `user_finances`
  ADD PRIMARY KEY (`user_finances_id`),
  ADD KEY `user_finances_ibfk_1` (`user_id`);

--
-- Indexes for table `user_roles`
--
ALTER TABLE `user_roles`
  ADD PRIMARY KEY (`user_role_id`),
  ADD UNIQUE KEY `user_role` (`user_role`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `car`
--
ALTER TABLE `car`
  MODIFY `car_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=168;

--
-- AUTO_INCREMENT for table `car_body_type`
--
ALTER TABLE `car_body_type`
  MODIFY `body_type_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `car_description`
--
ALTER TABLE `car_description`
  MODIFY `description_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `car_engine_fuel`
--
ALTER TABLE `car_engine_fuel`
  MODIFY `engine_fuel_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `car_images`
--
ALTER TABLE `car_images`
  MODIFY `image_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=190;

--
-- AUTO_INCREMENT for table `car_make`
--
ALTER TABLE `car_make`
  MODIFY `make_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `car_make_models`
--
ALTER TABLE `car_make_models`
  MODIFY `model_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `car_rent_cost`
--
ALTER TABLE `car_rent_cost`
  MODIFY `car_cost_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `car_transmission_type`
--
ALTER TABLE `car_transmission_type`
  MODIFY `transmission_type_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `rented_car`
--
ALTER TABLE `rented_car`
  MODIFY `rented_car_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `rented_cars_pickup_place`
--
ALTER TABLE `rented_cars_pickup_place`
  MODIFY `pickup_place_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `rented_car_cost`
--
ALTER TABLE `rented_car_cost`
  MODIFY `rented_car_cost_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `rented_car_damage`
--
ALTER TABLE `rented_car_damage`
  MODIFY `rented_car_damage_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `rented_car_insurance`
--
ALTER TABLE `rented_car_insurance`
  MODIFY `insurance_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `rented_car_status`
--
ALTER TABLE `rented_car_status`
  MODIFY `rented_car_status_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `user`
--
ALTER TABLE `user`
  MODIFY `user_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `user_finances`
--
ALTER TABLE `user_finances`
  MODIFY `user_finances_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `user_roles`
--
ALTER TABLE `user_roles`
  MODIFY `user_role_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `car`
--
ALTER TABLE `car`
  ADD CONSTRAINT `car_ibfk_1` FOREIGN KEY (`body_type_id`) REFERENCES `car_body_type` (`body_type_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `car_ibfk_2` FOREIGN KEY (`engine_fuel_id`) REFERENCES `car_engine_fuel` (`engine_fuel_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `car_ibfk_3` FOREIGN KEY (`model_id`) REFERENCES `car_make_models` (`model_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `car_ibfk_4` FOREIGN KEY (`transmission_type_id`) REFERENCES `car_transmission_type` (`transmission_type_id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Constraints for table `car_description`
--
ALTER TABLE `car_description`
  ADD CONSTRAINT `car_description_ibfk_1` FOREIGN KEY (`car_id`) REFERENCES `car` (`car_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `car_images`
--
ALTER TABLE `car_images`
  ADD CONSTRAINT `cars_images_ibfk-1` FOREIGN KEY (`car_id`) REFERENCES `car` (`car_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `car_make_models`
--
ALTER TABLE `car_make_models`
  ADD CONSTRAINT `car_make_models_ibfk_1` FOREIGN KEY (`make_id`) REFERENCES `car_make` (`make_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `car_rent_cost`
--
ALTER TABLE `car_rent_cost`
  ADD CONSTRAINT `car_rent_cost_ibfk_1` FOREIGN KEY (`car_id`) REFERENCES `car` (`car_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `rented_car`
--
ALTER TABLE `rented_car`
  ADD CONSTRAINT `rented_car_ibfk_1` FOREIGN KEY (`car_id`) REFERENCES `car` (`car_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `rented_car_ibfk_5` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `rented_car_ibfk_7` FOREIGN KEY (`car_pickup_place`) REFERENCES `rented_cars_pickup_place` (`pickup_place_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `rented_car_ibfk_8` FOREIGN KEY (`car_insurance`) REFERENCES `rented_car_insurance` (`insurance_id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Constraints for table `rented_car_cost`
--
ALTER TABLE `rented_car_cost`
  ADD CONSTRAINT `rented_car_cost_ibfk_1` FOREIGN KEY (`rented_car_id`) REFERENCES `rented_car` (`rented_car_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `rented_car_damage`
--
ALTER TABLE `rented_car_damage`
  ADD CONSTRAINT `rented_car_damage_ibfk_1` FOREIGN KEY (`rented_car_id`) REFERENCES `rented_car` (`rented_car_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `rented_car_status`
--
ALTER TABLE `rented_car_status`
  ADD CONSTRAINT `rented_car_status_ibfk_1` FOREIGN KEY (`rented_car_id`) REFERENCES `rented_car` (`rented_car_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `user`
--
ALTER TABLE `user`
  ADD CONSTRAINT `user_ibfk_1` FOREIGN KEY (`user_role_id`) REFERENCES `user_roles` (`user_role_id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Constraints for table `user_finances`
--
ALTER TABLE `user_finances`
  ADD CONSTRAINT `user_finances_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
