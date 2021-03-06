//
//  ScheduleTableViewController.swift
//  BSUIR Schedule
//
//  Created by Anton Borisenko on 7/11/20.
//  Copyright © 2020 Anton Borisenko. All rights reserved.
//

import UIKit
import Alamofire
import RealmSwift

// Main screen View Controller
class ScheduleTableViewController: UITableViewController {
    
    private var savedSchedules: Results<DBmodel>!   // Set of schedules saved in DB
    private var schedules = [Schedule]()            // Array of schedules parsed from DB models
    private var currentWeekNumber = 1               // Week number from 1 to 4, according to BSUIR API
    private var currentWeekDay = 0                  // Week day from 0 to 6 (mon, tue, etc.)
    private var currentScedule: Schedule?
    private var lessons = [LessonInfo]()            // Array of lessons for different days
    private var groupNumbers = [String]()           // All groups numbers
    
    // Label to display current week day, week number and group number
    @IBOutlet weak var weekDayNadNumberLabel: UILabel!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        addSwipeGestureRecognizers()
        
        // Getting current week number (from 1 to 4)
        NetworkManager.getCurrentWeekNumber() { (response) in
            self.currentWeekNumber = response
            self.currentWeekDay = ScheduleManager.getCurrentWeekDay()
            
            // Getting saved schedules from DB
            self.savedSchedules = realm.objects(DBmodel.self)
            
            
            for savedSchedule: DBmodel in self.savedSchedules {

                // Parsing data get from DB and appending to array of schedules
                let json = Data(savedSchedule.jsonRepresentationOfSchedule.utf8)
                do {
                    let schedule = try JSONDecoder().decode(Schedule.self, from: json)
                    self.schedules.append(schedule)
                } catch {
                    print(error)
                }
            }
            
            if !self.schedules.isEmpty {
                
                self.currentScedule = self.schedules[0]
                
                self.weekDayNadNumberLabel.text = ScheduleManager.getWeekDayAndNumber(
                    weekNumber: self.currentWeekNumber,
                    weekDay: self.currentWeekDay,
                    groupNumber: (self.currentScedule?.studentGroup.name)!
                )
                
                self.lessons = ScheduleManager.getCurrentDaySchedule(
                    weekNumber: self.currentWeekNumber,
                    weekDay: self.currentWeekDay,
                    schedule: self.currentScedule!
                )
                
                self.tableView.reloadData()
            }
        }
        
        NetworkManager.getAllGroupNumbers() { (groupNumbers) in

            self.groupNumbers = groupNumbers
        }
        
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lessons.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScheduleCell", for: indexPath) as! ScheduleTableViewCell
        
        guard !lessons.isEmpty else { return UITableViewCell() }
        
        let lesson = lessons[indexPath.row]
        
        cell.professorNameLabel.text = lesson.professorName
        cell.subjectNameLabel.text = lesson.subjectName
        cell.subjectTypeLabel.text = lesson.lessonType
        cell.subjectTimeLabel.text = lesson.lessonTime
        cell.subjectAuditoryLabel.text = lesson.auditorium
        if lesson.professorsPhoto != nil {
            cell.professorsPhoto.image = lesson.professorsPhoto
        } else {
            cell.professorsPhoto.image = #imageLiteral(resourceName: "silhouette")
        }
        
        return cell
    }

    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "Groups" {
            
            let newGroupVC = segue.destination as! NewGroupViewController
            
            for schedule in schedules {
                newGroupVC.groups.append(schedule.studentGroup)
            }
            newGroupVC.savedSchedules = savedSchedules
            newGroupVC.groupNumbers = groupNumbers
        }
        
    }
    
    @IBAction func unwindSegue(_ segue: UIStoryboardSegue) {

        guard let newGroupVC = segue.source as? NewGroupViewController else { return }
        
        newGroupVC.loadScheduleForNewGroup() { (schedule) in
            let json = Data(schedule.jsonRepresentationOfSchedule.utf8)
            do {
                let newSchedule = try JSONDecoder().decode(Schedule.self, from: json)
                if !self.schedules.contains(newSchedule) {
                    self.schedules.append(newSchedule)
                }
                self.currentScedule = newSchedule
                self.lessons = ScheduleManager.getCurrentDaySchedule(weekNumber: self.currentWeekNumber, weekDay: self.currentWeekDay, schedule: self.currentScedule!)
                self.tableView.reloadData()
            } catch {
                print(error)
            }
            
        }
        
        tableView.reloadData()
    }
    
    @IBAction func cancelAction(_ segue: UIStoryboardSegue) {
        
        savedSchedules = realm.objects(DBmodel.self)
        schedules.removeAll()
        
        for savedSchedule: DBmodel in savedSchedules {

            let json = Data(savedSchedule.jsonRepresentationOfSchedule.utf8)
            do {
                let schedule = try JSONDecoder().decode(Schedule.self, from: json)
                self.schedules.append(schedule)
            } catch {
                print(error)
            }
        }
    }
    
    // MARK: - Gesture Recognizing
    
    func addSwipeGestureRecognizers() {
        
        let rightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        rightGestureRecognizer.direction = .right
        self.view.addGestureRecognizer(rightGestureRecognizer)
        
        let leftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        leftGestureRecognizer.direction = .left
        self.view.addGestureRecognizer(leftGestureRecognizer)
    }

    // If swipe direction is right, we need to increase date (set tomorrow date) and update schedule in table view
    @objc func handleSwipe(gesture: UIGestureRecognizer) {
        
        if let gesture = gesture as? UISwipeGestureRecognizer {
            
            switch gesture.direction {
            case .right:
                guard self.currentScedule != nil else { return }
                
                changeCurrentWeekDay(increase: false)
                self.weekDayNadNumberLabel.text = ScheduleManager.getWeekDayAndNumber(
                    weekNumber: self.currentWeekNumber,
                    weekDay: self.currentWeekDay,
                    groupNumber: (self.currentScedule?.studentGroup.name)!
                )
                self.lessons = ScheduleManager.getCurrentDaySchedule(weekNumber: currentWeekNumber, weekDay: currentWeekDay, schedule: currentScedule!)
                self.tableView.reloadData()
            case .left:
                guard self.currentScedule != nil else { return }
                
                changeCurrentWeekDay(increase: true)
                self.weekDayNadNumberLabel.text = ScheduleManager.getWeekDayAndNumber(
                    weekNumber: self.currentWeekNumber,
                    weekDay: self.currentWeekDay,
                    groupNumber: (self.currentScedule?.studentGroup.name)!
                )
                self.lessons = ScheduleManager.getCurrentDaySchedule(weekNumber: currentWeekNumber, weekDay: currentWeekDay, schedule: currentScedule!)
                self.tableView.reloadData()
            default:
                break
            }
        }
    }
    
    func changeCurrentWeekDay(increase: Bool) {
        
        if increase {
            self.currentWeekDay += 1
            if self.currentWeekDay > 6 {
                self.currentWeekNumber += 1
                self.currentWeekDay = 0
                if self.currentWeekNumber > 4 {
                    self.currentWeekNumber = 1
                }
            }
        } else {
            self.currentWeekDay -= 1
            if self.currentWeekDay < 0 {
                self.currentWeekNumber -= 1
                self.currentWeekDay = 6
                if self.currentWeekNumber < 1 {
                    self.currentWeekNumber = 4
                }
            }
        }
    }
    
}
