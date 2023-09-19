
;;;;;;;;;;;;
;; 
;; ARM MOVEMENT SIMPLE MODEL - New version
;;
;; used buffers :: goal, visual, manual, retrieval buffer
;;
;;;;;;;;;;;;

(clear-all)

(define-model arm-movement-model
    
  (sgp :v t :esc t :egs 0.0 :ul t :ult t)
  ;;(sgp :lf .1)
  (sgp :show-focus t :trace-detail low)
  
  (sgp :save-buffer-trace t)

  (sgp :ul t :ult t)
  ;(sgp :utility-offsets utility-output)
  ;(sgp :utility-hook utility-switch)
  
  (sgp :bold-inc .1)
  
  ;;; SGP of buffer/module history
  (sgp :save-p-history t)
  (sgp :save-dm-history t)
  (sgp :save-buffer-history t)
  
  (sgp :set-resistance-threshold 0.9)
  
  
  ;;goal chunk type
  (chunk-type arm-move angle force state task)
  
  ;;imaginal chunk type
  (chunk-type check-task angle force)
  
  (add-dm
   (first-goal isa arm-move angle 0 state nil task arm)
   )
  
  ;;first-movement
  (P do-first-movement
     =goal>
       state nil
   ==>
     =goal>
       state first
     +manual>
       cmd arm-movement
       peak 90
       ang-vel 7
  )
  
  (P init-first-movement
     =goal>
       state first
     ?manual>
       state free
   ==>
     =goal>
     state check
     )
  
  (P check-movement
     =goal>
       state check
     ?imaginal>
       state free  
     !bind! =ang (get-angle-arm-movement (mp-time))
     !bind! =for (get-resistance-for-arm)  
  ==>
     =goal>
       state init
       angle =ang
       force =for
     )  
  
  (P movement-continuation
     =goal>
       state init
       angle =ang
       force 0  
  ==>
  =goal>
    state check
   +imaginal>
     isa check-task
     angle =ang
     force 0
     )
  
  (P movement-re-control
     =goal>
       state init
       force =for
    ; > force 0
  ==>
    !bind! =m (+ =for 7)    
    =goal>
    state check
   +manual>
     cmd arm-movement
     peak 90
     ang-vel =m
  )
  

 
  (goal-focus first-goal)
  
  ;(spp attend-an-letter :u 5)
  ;(spp check-the-task   :u 10)
  ;(spp check-intuitive-color :u 10)
  ;(spp check-intuitive-letter :u 10)
  
  ;(spp action-incongruent-stroop :reward 20)
  ;(spp action-congruent-stroop :reward 0)
    
    )
