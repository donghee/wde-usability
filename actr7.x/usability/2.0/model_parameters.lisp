
;;;;;;;;;;;;
;; 
;; INPUT MODEL PARAMETERS MODULE - first version
;;
;; Hyungseok Oh
;;
;;;;;;;;;;;;
;;
;; This module processes input values in the digital human twin
;;
;;;;;;;;;;;;
;;
;; 2013.07.16
;; ** Initial creation of the module
;;
;;;;;;;;;;;;

(defun init-model-parameters ()
  (setf *WORKLOAD* nil)
  (setf *UTILITY* nil)
  )

;;;;;;;;;;;;
;;;
;;; Input model parameters 
;;;
;;;;;;;;;;;;

(defun setting-twin-parameters-for-model (setting)
  ;;;
  ;;; Setting Model Parameters
  ;;;
  (let ((cognitive-ability (get-value-twin-cognitive-ability))
	(task-inform (get-value-task-information)))
  
    ;;;latency factor
    (if cognitive-ability
	(cond ((equal cognitive-ability "high") (set-parameter-value :lf 0.1))
	      ((equal cognitive-ability "low")  (set-parameter-value :lf 1.0)))
      (set-parameter-value :lf 0.1)) ;;defalut value
    
    
    ;;;task information
    (when (> (list-length task-inform) 0)
      (cond ((string= (first task-inform) "arm")
	       (set-arm-movement-task-parameters task-inform))))
    ))


;;;;;;;;;;;;
;;;
;;; Output model parameters 
;;;
;;;;;;;;;;;;

(defun output-performance-parameter ()
  (let ((value 0))
    value
  ))

(defun output-ACT-R-model-output-parameter (trace)
  (let ((result nil))
    (dolist (x trace)
      ;(setf result (append result (list (fourth x)))))
      (setf result (append result (list (split-by-space (fourth x))))))
    
    (input-ACT-R-model-output result)
    ))

;;;
;;; PARSING STRING FUNCTION
;;;
 (defun parsing-helper (input-string)
  (let ((start (position #\   input-string)))
    (if start
        (let ((end (position #\  input-string :start (+ start 1))))
          (if end
              (cons (subseq input-string (+ start 1) end)
                    (split-by-space (subseq input-string end)))
            (list (subseq input-string (+ start 1)))))
      nil)))

 (defun split-by-space (input-string)
  (let ((start (position #\  input-string)))
    (if (and start (> start 0))
        (remove-if (lambda (s) (string-equal s "")) (parsing-helper (concatenate 'string " " input-string)))
      (remove-if (lambda (s) (string-equal s "")) (parsing-helper input-string)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LEARNABILITY - ReControl rate
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun output-learnability-parameter ()
  (let ((value 0)
	(output-list (get-value-ACT-R-model-output))
	(continuation 0)
	(recontrol 0))
    
    (dolist (output output-list)
      (when (equal (third output) "PRODUCTION-FIRED")
	(cond ((equal (fourth output) "MOVEMENT-CONTINUATION") (incf continuation 1))
	      ((equal (fourth output) "MOVEMENT-RE-CONTROL") (incf recontrol 1)))))
    
    (setf value (floor (+ (act-r-noise (get-value-twin-noise)) (* 100 (/ continuation (+ continuation recontrol))))))
    
    (input-learnability-parameter value)
  ))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MEMORABILITY - NOT YET!!
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun output-memorability-parameter ()
  (let ((value 0))
    (input-memorability-parameter value)
  ))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; UTILITY - satisfaction??
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun output-utility-parameter ()
  (let ((value 0)
	(main-task nil))
    
    (cond ((equal (first (get-value-task-information)) "arm") (setf main-task 'arm))
	  )
    
    (setf value (floor (+ (act-r-noise (get-value-twin-noise)) (get-total-utility-no-decay main-task))))
    (input-utility-parameter value)
    ))

(defparameter *UTILITY* nil)
(defparameter *SAVE-UTILITY* t)

(defun get-subtask-utility ()
  (let ((pb (make-workload :buffer 'production :value 0 :weight 0 :active nil :s-time 0.0 :e-time 0.0))
        (vb (make-workload :buffer 'visual     :value 0 :weight 0 :active nil :s-time 0.0 :e-time 0.0))
        (rb (make-workload :buffer 'retrieval  :value 0 :weight 1 :active nil :s-time 0.0 :e-time 0.0))
        (ib (make-workload :buffer 'imaginal   :value 0 :weight 1 :active nil :s-time 0.0 :e-time 0.0))
        (mb (make-workload :buffer 'manual     :value 0 :weight 0 :active nil :s-time 0.0 :e-time 0.0))
        (task nil)
        (pre-task nil))

    (dolist (current-buffer-record (get-current-buffer-trace)) ;;buffer-record every mstime
      (let* ((mstime       (buffer-record-ms-time current-buffer-record))  
             (buffers      (buffer-record-buffers current-buffer-record))
             (goal-buffer  (nth 6 buffers)) ;;goal buffer is 2nd buffer of buffer-records
             (goal-chunk   (buffer-summary-chunk-name goal-buffer))
             (goal-request (buffer-summary-request goal-buffer)))

        (when (and goal-chunk (get-chunk (read-from-string goal-chunk)))
          (setf task 
                (cdr (assoc 'TASK (act-r-chunk-slot-value-lists (get-chunk (read-from-string goal-chunk)))))))
        
        (when goal-request
          (setf task
                (read-from-string (second (member "TASK" (split-by-space goal-request) :test #'equal)))))

        (when (and pre-task (not (eq task pre-task))) ;;TASK CHANGED
          (let ((value  (+ (workload-value pb) 
                           (workload-value vb) 
                           (workload-value rb) 
                           (workload-value ib) 
                           (workload-value mb))))
            ;(format t "~%TASK: ~a // VALUE: ~f" task value)
            (push (make-workload-reference :value value :task pre-task :time (/ mstime 1000)) *UTILITY*))
          
          ;;workload initiation
          (setf pb (make-workload :buffer 'production :value 0 :weight 0 :active nil :s-time 0.0 :e-time 0.0))
          (setf vb (make-workload :buffer 'visual     :value 0 :weight 0 :active nil :s-time 0.0 :e-time 0.0))
          (setf rb (make-workload :buffer 'retrieval  :value 0 :weight 1 :active nil :s-time 0.0 :e-time 0.0))
          (setf ib (make-workload :buffer 'imaginal   :value 0 :weight 1 :active nil :s-time 0.0 :e-time 0.0))
          (setf mb (make-workload :buffer 'manual     :value 0 :weight 0 :active nil :s-time 0.0 :e-time 0.0)))

        (setf pre-task task)
          
        (dolist (buffer buffers)
          (case (buffer-summary-name buffer)
              ((production) (get-buffer-workload pb buffer mstime *SAVE-UTILITY*))
              ((visual)     (get-buffer-workload vb buffer mstime *SAVE-UTILITY*))
              ((retrieval)  (get-buffer-workload rb buffer mstime *SAVE-UTILITY*))
              ((imaginal)   (get-buffer-workload ib buffer mstime *SAVE-UTILITY*))
              ((manual)     (get-buffer-workload mb buffer mstime *SAVE-UTILITY*))))))

     (let ((value  (+ (workload-value pb) 
                      (workload-value vb) 
                      (workload-value rb) 
                      (workload-value ib) 
                      (workload-value mb))))
       (push (make-workload-reference :value value :task task :time  (mp-time)) *UTILITY*))))

(defun get-total-utility-no-decay (task)
  (let ((total 0)
	(ctime (mp-time)))
    
    (get-subtask-utility)
    
    (dolist (ref *UTILITY*)
      (let* ((ctask (workload-reference-task ref))
             (rtime (- ctime (workload-reference-time ref)))
             (wv    (workload-reference-value ref))
             )
	(incf total wv)
	))
    
    (floor (* 100 (/ (- (* 2 (mp-time)) total) (* 2 (mp-time)))))
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EFFICIENCY - MENTAL WORKLOAD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun output-efficiency-parameter ()
  (let ((value 0)
	(main-task nil))
    
    (cond ((equal (first (get-value-task-information)) "arm") (setf main-task 'arm))
	  )
    
    (setf value (floor (+ (act-r-noise (get-value-twin-noise)) (get-total-workload main-task))))
    
    (input-mental-workload-parameter value)
    ))


;;;
;;; structure of workload
;;;
(defparameter *PRIMARY-GOAL* "FIRST-GOAL") ;;Input the name of the primary goal this parameter

(defparameter *SAVE-WORKLOAD* nil)
(defparameter *SCALE* 1.0)

(defparameter *SAVE-WORKLOAD* t)

(defparameter *WORKLOAD* nil)
(defparameter *WORKLOAD-LIST* nil)


(defparameter *THRESHOLD-WORKLOAD* 1.0)


(defstruct workload-reference
  value
  task
  time)
  
(defstruct workload 
  buffer
  value
  weight
  active
  s-time
  e-time)

(defun get-buffer-workload (buffer record mstime save)
  (cond ((and save 
              (not (workload-active buffer)) 
              (or (buffer-summary-busy record) (buffer-summary-request record)))
         (setf (workload-active buffer) t)
         (setf (workload-s-time buffer) (/ mstime 1000)))
        ((and (workload-active buffer) 
              (or (not (buffer-summary-busy record)) (buffer-summary-busy->free record) (buffer-summary-error record)))
         (setf (workload-active buffer) nil)
         (setf (workload-e-time buffer) (/ mstime 1000))
         (setf (workload-value buffer) (+ (workload-value buffer)
                                          (* (workload-weight buffer) 
                                             (- (workload-e-time buffer) (workload-s-time buffer))))))))


(defun get-subtask-workload ()
  (let ((pb (make-workload :buffer 'production :value 0 :weight 2 :active nil :s-time 0.0 :e-time 0.0))
        (vb (make-workload :buffer 'visual     :value 0 :weight 1 :active nil :s-time 0.0 :e-time 0.0))
        (rb (make-workload :buffer 'retrieval  :value 0 :weight 4 :active nil :s-time 0.0 :e-time 0.0))
        (ib (make-workload :buffer 'imaginal   :value 0 :weight 4 :active nil :s-time 0.0 :e-time 0.0))
        (mb (make-workload :buffer 'manual     :value 0 :weight 4 :active nil :s-time 0.0 :e-time 0.0))
        (task nil)
        (pre-task nil))

    (dolist (current-buffer-record (get-current-buffer-trace)) ;;buffer-record every mstime
      (let* ((mstime       (buffer-record-ms-time current-buffer-record))  
             (buffers      (buffer-record-buffers current-buffer-record))
             (goal-buffer  (nth 6 buffers)) ;;goal buffer is 2nd buffer of buffer-records
             (goal-chunk   (buffer-summary-chunk-name goal-buffer))
             (goal-request (buffer-summary-request goal-buffer)))

        (when (and goal-chunk (get-chunk (read-from-string goal-chunk)))
          (setf task 
                (cdr (assoc 'TASK (act-r-chunk-slot-value-lists (get-chunk (read-from-string goal-chunk)))))))
        
        (when goal-request
          (setf task
                (read-from-string (second (member "TASK" (split-by-space goal-request) :test #'equal)))))

        (when (and pre-task (not (eq task pre-task))) ;;TASK CHANGED
          (let ((value  (+ (workload-value pb) 
                           (workload-value vb) 
                           (workload-value rb) 
                           (workload-value ib) 
                           (workload-value mb))))
            ;(format t "~%TASK: ~a // VALUE: ~f" task value)
            (push (make-workload-reference :value value :task pre-task :time (/ mstime 1000)) *WORKLOAD*))
          
          ;;workload initiation
          (setf pb (make-workload :buffer 'production :value 0 :weight 2 :active nil :s-time 0.0 :e-time 0.0))
          (setf vb (make-workload :buffer 'visual     :value 0 :weight 1 :active nil :s-time 0.0 :e-time 0.0))
          (setf rb (make-workload :buffer 'retrieval  :value 0 :weight 4 :active nil :s-time 0.0 :e-time 0.0))
          (setf ib (make-workload :buffer 'imaginal   :value 0 :weight 4 :active nil :s-time 0.0 :e-time 0.0))
          (setf mb (make-workload :buffer 'manual     :value 0 :weight 4 :active nil :s-time 0.0 :e-time 0.0)))

        (setf pre-task task)
          
        (dolist (buffer buffers)
          (case (buffer-summary-name buffer)
              ((production) (get-buffer-workload pb buffer mstime *SAVE-WORKLOAD*))
              ((visual)     (get-buffer-workload vb buffer mstime *SAVE-WORKLOAD*))
              ((retrieval)  (get-buffer-workload rb buffer mstime *SAVE-WORKLOAD*))
              ((imaginal)   (get-buffer-workload ib buffer mstime *SAVE-WORKLOAD*))
              ((manual)     (get-buffer-workload mb buffer mstime *SAVE-WORKLOAD*))))))

     (let ((value  (+ (workload-value pb) 
                      (workload-value vb) 
                      (workload-value rb) 
                      (workload-value ib) 
                      (workload-value mb))))
       (push (make-workload-reference :value value :task task :time  (mp-time)) *WORKLOAD*))))

             
;;;
;;; DECAY FUNCTION
;;;
(defparameter *decay* .5);0.156);.6)

(defun get-workload-including-decay (task reference decay ctime) ;;(WORKLOAD-DELAY 'MEMORY *WORKLOAD* (mp-time))
  (let ((total 0))
    (dolist (ref reference)
      (let* ((ctask (workload-reference-task ref))
             (rtime (- ctime (workload-reference-time ref)))
             (wv    (workload-reference-value ref))
             (tv    (if (= rtime 0) wv (* wv (expt rtime (* decay -1))))))
        ;(when (eq ctask task) (incf total tv))
	(incf total tv)
	))
    total
    ))

(defun get-workload-no-decay (task reference ctime)
  (let ((total 0))
    (dolist (ref reference)
      (let* ((ctask (workload-reference-task ref))
             (rtime (- ctime (workload-reference-time ref)))
             (wv    (workload-reference-value ref))
             )
	(incf total wv)
	))
    total
    ))

;;;
;;; TOTAL WORKLOAD
;;;
(defun get-total-workload (task)
  (get-subtask-workload)
  ;(get-workload-including-decay task *WORKLOAD* *decay* (mp-time))
  (floor (* 100 (/ (get-workload-no-decay task *WORKLOAD* (mp-time)) (* 15 (mp-time)))))
  )      

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EFFECTIVENESS - HUMAN ERROR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun output-effectiveness-parameter ()
  (let ((value 0)
	(force (get-value-device-force-timeline)))
    
    (setf value (floor (- 100 (+ force (act-r-noise (get-value-twin-noise))))))
    (input-human-error-parameter value)
    (input-effectiveness-parameter value)
  ))


  